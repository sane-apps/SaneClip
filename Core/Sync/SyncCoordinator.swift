#if ENABLE_SYNC

    import CloudKit
    import Foundation
    import os.log
    #if os(macOS)
        import Security
    #endif

    #if os(iOS)
        import UIKit
    #endif

    /// Main sync orchestrator. Implements CKSyncEngineDelegate to handle
    /// bidirectional sync between local clipboard history and iCloud.
    ///
    /// Active in any build that compiles with ENABLE_SYNC.
    /// For SaneClip today that includes direct-download Release builds and
    /// App Store builds, so CloudKit production schema must be ready before
    /// shipping either channel.
    @MainActor
    @Observable
    class SyncCoordinator: NSObject, CKSyncEngineDelegate {
        static let shared = SyncCoordinator()

        // MARK: - Published State

        var isSyncEnabled: Bool = false {
            didSet {
                UserDefaults.standard.set(isSyncEnabled, forKey: "syncEnabled")
                if isSyncEnabled {
                    startSync()
                } else {
                    stopSync()
                }
            }
        }

        var syncStatus: SyncStatus = .idle
        var lastSyncDate: Date?
        var connectedDevices: [String] = []

        #if os(iOS)
            /// On iOS, synced items received from other devices are stored here.
            /// The ClipboardHistoryViewModel observes this array.
            var syncedItems: [SharedClipboardItem] = []
        #endif

        enum SyncStatus: String {
            case idle = "Idle"
            case syncing = "Syncing..."
            case error = "Error"
            case disabled = "Disabled"
            case noAccount = "No iCloud Account"
            case unavailable = "Unavailable in This Build"
        }

        // MARK: - Private State

        private var syncEngine: CKSyncEngine?
        private var container: CKContainer?
        private let logger = Logger(subsystem: "com.saneclip.app", category: "Sync")
        private var pendingRecordIDs: Set<CKRecord.ID> = []
        private var isInitialLocalSeedPending = false {
            didSet {
                UserDefaults.standard.set(isInitialLocalSeedPending, forKey: Self.initialLocalSeedPendingKey)
            }
        }
        private var awaitingInitialZoneBootstrap = false
        #if os(iOS)
            private var pendingIOSItemsByID: [UUID: SharedClipboardItem] = [:]
        #endif
        private static let containerIdentifier = "iCloud.com.saneclip.app"
        private static let initialLocalSeedPendingKey = "syncInitialLocalSeedPending"

        private let deviceId: String = {
            #if os(macOS)
                return Host.current().localizedName ?? "Mac"
            #else
                return UIDevice.current.name
            #endif
        }()

        private let deviceName: String = {
            #if os(macOS)
                return "Mac"
            #else
                return UIDevice.current.model
            #endif
        }()

        // MARK: - State Persistence

        private var stateFileURL: URL {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appFolder = appSupport.appendingPathComponent("SaneClip", isDirectory: true)
            try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
            return appFolder.appendingPathComponent("sync_state.data")
        }

        private func loadStateSerialization() -> CKSyncEngine.State.Serialization? {
            guard let data = try? Data(contentsOf: stateFileURL) else { return nil }
            return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
        }

        private func saveStateSerialization(_ serialization: CKSyncEngine.State.Serialization) {
            do {
                let data = try JSONEncoder().encode(serialization)
                try data.write(to: stateFileURL, options: .atomic)
            } catch {
                logger.error("Failed to save sync state: \(error.localizedDescription)")
            }
        }

        // MARK: - Lifecycle

        override init() {
            let savedEnabled = UserDefaults.standard.bool(forKey: "syncEnabled")
            super.init()
            isSyncEnabled = savedEnabled
            isInitialLocalSeedPending = UserDefaults.standard.bool(forKey: Self.initialLocalSeedPendingKey)
            if savedEnabled, Self.hasCloudKitCapability {
                startSync()
            } else if savedEnabled {
                isSyncEnabled = false
                syncStatus = .unavailable
                logger.error("CloudKit sync unavailable: missing iCloud/CloudKit entitlement for this build")
            }
        }

        func startSync() {
            guard syncEngine == nil else { return }
            guard Self.hasCloudKitCapability else {
                syncStatus = .unavailable
                logger.error("CloudKit sync unavailable: missing iCloud/CloudKit entitlement for this build")
                isSyncEnabled = false
                return
            }

            if container == nil {
                container = CKContainer(identifier: Self.containerIdentifier)
            }
            guard let container else {
                syncStatus = .unavailable
                logger.error("CloudKit sync unavailable: container initialization failed")
                isSyncEnabled = false
                return
            }

            let previousState = loadStateSerialization()
            let configuration = CKSyncEngine.Configuration(
                database: container.privateCloudDatabase,
                stateSerialization: previousState,
                delegate: self
            )

            syncEngine = CKSyncEngine(configuration)
            syncStatus = .syncing

            // Ensure our custom zone exists
            let zoneChange = CKSyncEngine.PendingDatabaseChange.saveZone(
                CKRecordZone(zoneID: SyncDataModel.zoneID)
            )
            syncEngine?.state.add(pendingDatabaseChanges: [zoneChange])
            if let syncEngine {
                pendingRecordIDs = Self.pendingSaveRecordIDs(from: syncEngine.state.pendingRecordZoneChanges)
            } else {
                pendingRecordIDs.removeAll()
            }
            awaitingInitialZoneBootstrap = Self.shouldQueueInitialLocalSeedAfterZoneBootstrap(
                previousStateExists: previousState != nil,
                savedZoneCount: 1
            )
            if isInitialLocalSeedPending, pendingRecordIDs.isEmpty, previousState != nil {
                isInitialLocalSeedPending = false
            }

            logger.info("Sync engine started")
        }

        func stopSync(setStatusToDisabled: Bool = true) {
            syncEngine = nil
            pendingRecordIDs.removeAll()
            if setStatusToDisabled {
                syncStatus = .disabled
            }
            logger.info("Sync engine stopped")
        }

        private static var hasCloudKitCapability: Bool {
            #if os(iOS)
                return true
            #else
            guard let task = SecTaskCreateFromSelf(nil) else { return false }

            let containerIdentifiers = entitlementStrings(
                for: "com.apple.developer.icloud-container-identifiers",
                task: task
            )
            let services = entitlementStrings(
                for: "com.apple.developer.icloud-services",
                task: task
            )

            return containerIdentifiers.contains(containerIdentifier) && services.contains("CloudKit")
            #endif
        }

        #if os(macOS)
        private static func entitlementStrings(for key: String, task: SecTask) -> [String] {
            var error: Unmanaged<CFError>?
            guard let rawValue = SecTaskCopyValueForEntitlement(task, key as CFString, &error) else {
                return []
            }

            if let values = rawValue as? [String] {
                return values
            }
            if let value = rawValue as? String {
                return [value]
            }
            if let values = rawValue as? NSArray {
                return values.compactMap { $0 as? String }
            }
            return []
        }
        #endif

        nonisolated static func initialRecordNamesToSeed(
            historyIDs: [UUID],
            pendingRecordNames: Set<String>
        ) -> [String] {
            historyIDs.map(\.uuidString).filter { !pendingRecordNames.contains($0) }
        }

        nonisolated static func initialLocalSeedItems(
            items: [SharedClipboardItem],
            pendingRecordNames: Set<String>
        ) -> [SharedClipboardItem] {
            items.filter { !pendingRecordNames.contains($0.id.uuidString) }
        }

        nonisolated static func pendingSaveRecordIDs(
            from changes: [CKSyncEngine.PendingRecordZoneChange]
        ) -> Set<CKRecord.ID> {
            Set(changes.compactMap { change in
                guard case let .saveRecord(recordID) = change else { return nil }
                return recordID
            })
        }

        nonisolated static func shouldApplyRemoteDeletions(
            isInitialLocalSeedPending: Bool,
            pendingRecordCount: Int
        ) -> Bool {
            !isInitialLocalSeedPending || pendingRecordCount == 0
        }

        nonisolated static func shouldResetSyncState(forDeletedZoneIDs zoneIDs: [CKRecordZone.ID]) -> Bool {
            zoneIDs.contains(SyncDataModel.zoneID)
        }

        nonisolated static func shouldQueueInitialLocalSeedAfterZoneBootstrap(
            previousStateExists: Bool,
            savedZoneCount: Int
        ) -> Bool {
            !previousStateExists && savedZoneCount > 0
        }

        nonisolated static func postBootstrapSeedFollowUp(seededRecordCount: Int) -> PostBootstrapSeedFollowUp {
            seededRecordCount > 0 ? .waitForAutomaticSend : .none
        }

        @discardableResult
        private func queueInitialLocalSeedIfNeeded() -> Int {
            guard awaitingInitialZoneBootstrap,
                  let syncEngine else { return 0 }

            let pendingRecordNames = Set(
                Self.pendingSaveRecordIDs(from: syncEngine.state.pendingRecordZoneChanges).map(\.recordName)
            )
            let itemsToSeed = Self.initialLocalSeedItems(
                items: localSeedItems(),
                pendingRecordNames: pendingRecordNames
            )
            awaitingInitialZoneBootstrap = false
            guard !itemsToSeed.isEmpty else { return 0 }

            let recordIDs = Set(itemsToSeed.map { item in
                CKRecord.ID(recordName: item.id.uuidString, zoneID: SyncDataModel.zoneID)
            })
            let changes = recordIDs.map(CKSyncEngine.PendingRecordZoneChange.saveRecord)
            syncEngine.state.add(pendingRecordZoneChanges: changes)
            pendingRecordIDs.formUnion(recordIDs)
            #if os(iOS)
                for item in itemsToSeed {
                    pendingIOSItemsByID[item.id] = item
                }
            #endif
            isInitialLocalSeedPending = true
            logger.info("Queued \(itemsToSeed.count) existing history items for initial sync")
            return itemsToSeed.count
        }

        private func localSeedItems() -> [SharedClipboardItem] {
            #if os(macOS)
                guard let manager = ClipboardManager.shared else { return [] }
                return manager.history.map { item in
                    SharedClipboardItem(
                        id: item.id,
                        content: item.sharedContent,
                        timestamp: item.timestamp,
                        sourceAppBundleID: item.sourceAppBundleID,
                        sourceAppName: item.sourceAppName,
                        pasteCount: item.pasteCount,
                        note: item.note,
                        deviceId: deviceId,
                        deviceName: deviceName
                    )
                }
            #else
                guard let container = IOSHistoryDataContainer.load() else { return [] }
                return container.recentItems.compactMap(SharedClipboardItem.init(storedItem:))
            #endif
        }

        func syncNow() async {
            guard isSyncEnabled, let syncEngine else { return }

            syncStatus = .syncing
            logger.info("Manual sync requested: pendingRecords=\(self.pendingRecordIDs.count)")

            do {
                try await syncEngine.sendChanges()
                try await syncEngine.fetchChanges()
                logger.info("Manual sync cycle completed")
            } catch let error as CKError {
                applySyncFailure(for: error, message: "Manual sync failed")
            } catch {
                syncStatus = .error
                logger.error("Manual sync failed: \(error.localizedDescription)")
            }
        }

        // MARK: - Queue Local Changes

        /// Called by ClipboardManager when a new item is captured or modified.
        func queueItemForSync(_ item: SharedClipboardItem) {
            guard let syncEngine, isSyncEnabled else { return }

            let recordID = CKRecord.ID(
                recordName: item.id.uuidString,
                zoneID: SyncDataModel.zoneID
            )
            pendingRecordIDs.insert(recordID)
            #if os(iOS)
                pendingIOSItemsByID[item.id] = item
            #endif

            syncEngine.state.add(pendingRecordZoneChanges: [
                .saveRecord(recordID)
            ])

            logger.debug("Queued item for sync: \(item.id)")
        }

        /// Queue a delete operation for a removed item.
        func queueDeleteForSync(itemID: UUID) {
            guard let syncEngine, isSyncEnabled else { return }

            let recordID = CKRecord.ID(
                recordName: itemID.uuidString,
                zoneID: SyncDataModel.zoneID
            )

            syncEngine.state.add(pendingRecordZoneChanges: [
                .deleteRecord(recordID)
            ])
            #if os(iOS)
                pendingIOSItemsByID.removeValue(forKey: itemID)
            #endif

            logger.debug("Queued delete for sync: \(itemID)")
        }

        // MARK: - CKSyncEngineDelegate

        nonisolated func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
            await MainActor.run {
                self.processEvent(event, syncEngine: syncEngine)
            }
        }

        nonisolated func nextRecordZoneChangeBatch(
            _ context: CKSyncEngine.SendChangesContext,
            syncEngine: CKSyncEngine
        ) async -> CKSyncEngine.RecordZoneChangeBatch? {
            // Collect records on MainActor first, then build batch outside
            let (pending, recordsByID, missingRecordIDs) = await MainActor.run {
                let scope = context.options.scope
                let filtered = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
                var records: [CKRecord.ID: CKRecord] = [:]
                var missingRecordIDs: [CKRecord.ID] = []
                for change in filtered {
                    if case let .saveRecord(recordID) = change {
                        if let record = try? self.buildRecordForID(recordID) {
                            records[recordID] = record
                        } else {
                            missingRecordIDs.append(recordID)
                        }
                    }
                }
                return (filtered, records, missingRecordIDs)
            }

            guard !pending.isEmpty else { return nil }
            logger.info(
                "Preparing record batch: pendingChanges=\(pending.count) saveRecords=\(recordsByID.count) missingRecords=\(missingRecordIDs.count)"
            )
            if !missingRecordIDs.isEmpty {
                let names = missingRecordIDs.map(\.recordName).joined(separator: ",")
                logger.error("Missing local records for sync batch: \(names, privacy: .public)")
            }

            return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { recordID in
                recordsByID[recordID]
            }
        }

        // MARK: - Event Processing

        private func processEvent(_ event: CKSyncEngine.Event, syncEngine _: CKSyncEngine) {
            switch event {
            case let .stateUpdate(stateUpdate):
                saveStateSerialization(stateUpdate.stateSerialization)

            case let .accountChange(accountChange):
                handleAccountChange(accountChange)

            case let .fetchedRecordZoneChanges(changes):
                handleFetchedChanges(changes)

            case let .sentRecordZoneChanges(sentChanges):
                handleSentChanges(sentChanges)

            case let .fetchedDatabaseChanges(dbChanges):
                handleFetchedDatabaseChanges(dbChanges)

            case let .sentDatabaseChanges(sentDB):
                handleSentDatabaseChanges(sentDB)

            case let .didFetchRecordZoneChanges(fetchResult):
                handleDidFetchRecordZoneChanges(fetchResult)

            case .didSendChanges:
                break

            case .willFetchChanges, .willFetchRecordZoneChanges,
                 .willSendChanges,
                 .didFetchChanges:
                break // Progress events we don't need to act on

            @unknown default:
                logger.warning("Unknown sync event: \(String(describing: event))")
            }
        }

        // MARK: - Handle Fetched Changes

        private func handleFetchedChanges(_ changes: CKSyncEngine.Event.FetchedRecordZoneChanges) {
            for modification in changes.modifications {
                do {
                    let shared = try SyncDataModel.decode(modification.record)
                    // Don't re-import our own device's items
                    guard shared.deviceId != deviceId else { continue }

                    notifyNewSyncedItem(shared)
                    logger.debug("Received synced item from \(shared.deviceName): \(shared.id)")

                    // Track connected devices
                    if !shared.deviceName.isEmpty, !connectedDevices.contains(shared.deviceName) {
                        connectedDevices.append(shared.deviceName)
                    }
                } catch {
                    logger.error("Failed to decode synced record: \(error.localizedDescription)")
                }
            }

            if Self.shouldApplyRemoteDeletions(
                isInitialLocalSeedPending: isInitialLocalSeedPending,
                pendingRecordCount: pendingRecordIDs.count
            ) {
                for deletion in changes.deletions {
                    let itemID = UUID(uuidString: deletion.recordID.recordName)
                    if let itemID {
                        notifyDeletedSyncedItem(itemID)
                    }
                }
            } else if !changes.deletions.isEmpty {
                logger.warning("Skipping \(changes.deletions.count) remote deletions while initial local history seed is pending")
            }

            lastSyncDate = Date()
            syncStatus = .idle
        }

        // MARK: - Handle Sent Changes

        private func handleSentChanges(_ sentChanges: CKSyncEngine.Event.SentRecordZoneChanges) {
            logger.info(
                "Sent record changes: saved=\(sentChanges.savedRecords.count) failedSaves=\(sentChanges.failedRecordSaves.count) failedDeletes=\(sentChanges.failedRecordDeletes.count)"
            )
            // Remove successful saves from pending
            for saved in sentChanges.savedRecords {
                pendingRecordIDs.remove(saved.recordID)
                #if os(iOS)
                    if let savedID = UUID(uuidString: saved.recordID.recordName) {
                        pendingIOSItemsByID.removeValue(forKey: savedID)
                    }
                #endif
            }

            // Handle failures
            for failure in sentChanges.failedRecordSaves {
                let error = failure.error
                if error.code == .serverRecordChanged,
                   let serverRecord = error.serverRecord {
                    // Conflict — resolve it
                    if let clientRecord = try? buildRecordForID(failure.record.recordID) {
                        if let merged = SyncConflictResolver.resolve(
                            clientRecord: clientRecord,
                            serverRecord: serverRecord
                        ) {
                            // Re-queue the merged record
                            pendingRecordIDs.insert(merged.recordID)
                            syncEngine?.state.add(pendingRecordZoneChanges: [
                                .saveRecord(merged.recordID)
                            ])
                        }
                        // If nil, server won — no action needed
                    }
                } else {
                    applySyncFailure(for: error, message: "Failed to save record \(failure.record.recordID)")
                }
            }

            for (recordID, error) in sentChanges.failedRecordDeletes {
                applySyncFailure(for: error, message: "Failed to delete record \(recordID)")
            }

            if isInitialLocalSeedPending, pendingRecordIDs.isEmpty {
                isInitialLocalSeedPending = false
            }

            let hadFailures = !sentChanges.failedRecordSaves.isEmpty || !sentChanges.failedRecordDeletes.isEmpty
            guard !hadFailures else {
                if syncStatus == .syncing {
                    syncStatus = .error
                }
                return
            }

            lastSyncDate = Date()
            syncStatus = .idle
        }

        private func buildRecordForID(_ recordID: CKRecord.ID) throws -> CKRecord? {
            #if os(macOS)
                guard let manager = ClipboardManager.shared,
                      let itemID = UUID(uuidString: recordID.recordName),
                      let item = manager.history.first(where: { $0.id == itemID })
                else {
                    return nil
                }

                let shared = SharedClipboardItem(
                    id: item.id,
                    content: item.sharedContent,
                    timestamp: item.timestamp,
                    sourceAppBundleID: item.sourceAppBundleID,
                    sourceAppName: item.sourceAppName,
                    pasteCount: item.pasteCount,
                    deviceId: deviceId,
                    deviceName: deviceName
                )

                let canUseHistoryEncryption = (manager.licenseService?.isPro == true) && SettingsModel.shared.encryptHistory
                return try SyncDataModel.encode(shared, encrypt: canUseHistoryEncryption)
            #else
                guard let itemID = UUID(uuidString: recordID.recordName),
                      let item = pendingIOSItemsByID[itemID]
                else {
                    return nil
                }
                return try SyncDataModel.encode(item, encrypt: false)
            #endif
        }

        // MARK: - Handle Database Changes

        private func handleFetchedDatabaseChanges(_ changes: CKSyncEngine.Event.FetchedDatabaseChanges) {
            let deletedZoneIDs = changes.deletions.map(\.zoneID)
            if Self.shouldResetSyncState(forDeletedZoneIDs: deletedZoneIDs) {
                logger.warning("Primary sync zone deleted on server — resetting local sync state and re-seeding history")
                try? FileManager.default.removeItem(at: stateFileURL)
                connectedDevices.removeAll()
                pendingRecordIDs.removeAll()
                isInitialLocalSeedPending = false
                stopSync()
                startSync()
                return
            }

            for deletion in changes.deletions {
                logger.info("Zone deleted from server: \(deletion.zoneID.zoneName)")
            }
        }

        private func handleSentDatabaseChanges(_ changes: CKSyncEngine.Event.SentDatabaseChanges) {
            for saved in changes.savedZones {
                logger.info("Zone created on server: \(saved.zoneID.zoneName)")
            }
            for failure in changes.failedZoneSaves {
                applySyncFailure(for: failure.error, message: "Failed to create zone")
            }
            for (zoneID, error) in changes.failedZoneDeletes {
                applySyncFailure(for: error, message: "Failed to delete zone \(zoneID.zoneName)")
            }

            let hadFailures = !changes.failedZoneSaves.isEmpty || !changes.failedZoneDeletes.isEmpty
            guard !hadFailures else {
                if syncStatus == .syncing {
                    syncStatus = .error
                }
                return
            }
            let seededRecordCount = queueInitialLocalSeedIfNeeded()
            if Self.postBootstrapSeedFollowUp(seededRecordCount: seededRecordCount) == .waitForAutomaticSend {
                syncStatus = .syncing
                logger.info("Queued initial local seed and waiting for CKSyncEngine to send pending records automatically")
                return
            }
            if !changes.savedZones.isEmpty || !changes.deletedZoneIDs.isEmpty {
                lastSyncDate = Date()
                syncStatus = .idle
            }
        }

        private func handleDidFetchRecordZoneChanges(_ fetchResult: CKSyncEngine.Event.DidFetchRecordZoneChanges) {
            guard let error = fetchResult.error else { return }
            applySyncFailure(for: error, message: "Failed to fetch zone changes")
        }

        // MARK: - Account Changes

        private func handleAccountChange(_ change: CKSyncEngine.Event.AccountChange) {
            switch change.changeType {
            case .signIn:
                logger.info("iCloud account signed in")
                syncStatus = .idle
            case .switchAccounts:
                logger.info("iCloud account switched — clearing sync state")
                // Clear local sync state for the old account
                try? FileManager.default.removeItem(at: stateFileURL)
                connectedDevices.removeAll()
                pendingRecordIDs.removeAll()
                isInitialLocalSeedPending = false
                stopSync()
                startSync()
            case .signOut:
                logger.info("iCloud account signed out")
                syncStatus = .noAccount
                pendingRecordIDs.removeAll()
                isInitialLocalSeedPending = false
                stopSync(setStatusToDisabled: false)
            @unknown default:
                break
            }
        }

        nonisolated static func status(for errorCode: CKError.Code) -> SyncStatus {
            switch errorCode {
            case .notAuthenticated:
                return .noAccount
            default:
                return .error
            }
        }

        nonisolated static func failureDiagnostic(message: String, error: CKError) -> String {
            let nsError = error as NSError
            var diagnostic = "\(message): domain=\(nsError.domain) code=\(error.code.rawValue) status=\(status(for: error.code).rawValue)"
            if !nsError.userInfo.isEmpty {
                let details = nsError.userInfo
                    .map { key, value in
                        "\(key)=\(String(describing: value))"
                    }
                    .sorted()
                    .joined(separator: "; ")
                diagnostic += " userInfo={\(details)}"
            }
            return diagnostic
        }

        private func applySyncFailure(for error: CKError, message: String) {
            syncStatus = Self.status(for: error.code)
            logger.error("\(Self.failureDiagnostic(message: message, error: error), privacy: .public)")
        }

        // MARK: - Notifications to Local Data Layer

        private func notifyNewSyncedItem(_ item: SharedClipboardItem) {
            #if os(macOS)
                guard let manager = ClipboardManager.shared else { return }
                if !manager.history.contains(where: { $0.id == item.id }) {
                    let clipItem = ClipboardItem(
                        id: item.id,
                        content: item.macOSContent,
                        timestamp: item.timestamp,
                        sourceAppBundleID: item.sourceAppBundleID,
                        sourceAppName: item.sourceAppName,
                        pasteCount: item.pasteCount
                    )
                    manager.insertSyncedItem(clipItem)
                }
            #else
                if !syncedItems.contains(where: { $0.id == item.id }) {
                    syncedItems.insert(item, at: 0)
                }
            #endif
        }

        private func notifyDeletedSyncedItem(_ itemID: UUID) {
            #if os(macOS)
                guard let manager = ClipboardManager.shared else { return }
                if manager.history.contains(where: { $0.id == itemID }) {
                    manager.deleteSyncedItem(itemID)
                }
            #else
                syncedItems.removeAll { $0.id == itemID }
            #endif
        }

        enum PostBootstrapSeedFollowUp {
            case none
            case waitForAutomaticSend
        }
    }

#endif
