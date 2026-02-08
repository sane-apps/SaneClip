#if ENABLE_SYNC

    import CloudKit
    import Foundation
    import os.log

    #if os(iOS)
        import UIKit
    #endif

    /// Main sync orchestrator. Implements CKSyncEngineDelegate to handle
    /// bidirectional sync between local clipboard history and iCloud.
    ///
    /// Only active in App Store builds (#if ENABLE_SYNC).
    /// Developer ID builds degrade gracefully — sync is simply unavailable.
    @MainActor
    @Observable
    class SyncCoordinator: NSObject, @preconcurrency CKSyncEngineDelegate {
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
        }

        // MARK: - Private State

        private var syncEngine: CKSyncEngine?
        private let container = CKContainer(identifier: "iCloud.com.saneclip.app")
        private let logger = Logger(subsystem: "com.saneclip.app", category: "Sync")
        private var pendingRecordIDs: Set<CKRecord.ID> = []

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
            if savedEnabled {
                startSync()
            }
        }

        func startSync() {
            guard syncEngine == nil else { return }

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

            logger.info("Sync engine started")
        }

        func stopSync() {
            syncEngine = nil
            syncStatus = .disabled
            logger.info("Sync engine stopped")
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

            logger.debug("Queued delete for sync: \(itemID)")
        }

        // MARK: - CKSyncEngineDelegate

        nonisolated func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) {
            Task { @MainActor in
                self.processEvent(event, syncEngine: syncEngine)
            }
        }

        nonisolated func nextRecordZoneChangeBatch(
            _ context: CKSyncEngine.SendChangesContext,
            syncEngine: CKSyncEngine
        ) async -> CKSyncEngine.RecordZoneChangeBatch? {
            // Collect records on MainActor first, then build batch outside
            let (pending, recordsByID) = await MainActor.run {
                let scope = context.options.scope
                let filtered = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
                var records: [CKRecord.ID: CKRecord] = [:]
                for change in filtered {
                    if case let .saveRecord(recordID) = change {
                        if let record = try? self.buildRecordForID(recordID) {
                            records[recordID] = record
                        }
                    }
                }
                return (filtered, records)
            }

            guard !pending.isEmpty else { return nil }

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

            case .willFetchChanges, .willFetchRecordZoneChanges,
                 .didFetchRecordZoneChanges, .willSendChanges, .didSendChanges,
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

            for deletion in changes.deletions {
                let itemID = UUID(uuidString: deletion.recordID.recordName)
                if let itemID {
                    notifyDeletedSyncedItem(itemID)
                }
            }

            lastSyncDate = Date()
            syncStatus = .idle
        }

        // MARK: - Handle Sent Changes

        private func handleSentChanges(_ sentChanges: CKSyncEngine.Event.SentRecordZoneChanges) {
            // Remove successful saves from pending
            for saved in sentChanges.savedRecords {
                pendingRecordIDs.remove(saved.recordID)
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
                            syncEngine?.state.add(pendingRecordZoneChanges: [
                                .saveRecord(merged.recordID)
                            ])
                        }
                        // If nil, server won — no action needed
                    }
                } else {
                    logger.error("Failed to save record \(failure.record.recordID): \(error.localizedDescription)")
                }
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

                return try SyncDataModel.encode(shared, encrypt: SettingsModel.shared.encryptHistory)
            #else
                // iOS is receive-only for now — no local clipboard items to upload
                return nil
            #endif
        }

        // MARK: - Handle Database Changes

        private func handleFetchedDatabaseChanges(_ changes: CKSyncEngine.Event.FetchedDatabaseChanges) {
            for deletion in changes.deletions {
                logger.info("Zone deleted from server: \(deletion.zoneID.zoneName)")
            }
        }

        private func handleSentDatabaseChanges(_ changes: CKSyncEngine.Event.SentDatabaseChanges) {
            for saved in changes.savedZones {
                logger.info("Zone created on server: \(saved.zoneID.zoneName)")
            }
            for failure in changes.failedZoneSaves {
                logger.error("Failed to create zone: \(failure.error.localizedDescription)")
            }
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
                stopSync()
                startSync()
            case .signOut:
                logger.info("iCloud account signed out")
                syncStatus = .noAccount
                stopSync()
            @unknown default:
                break
            }
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
    }

#endif
