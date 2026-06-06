import SwiftUI
import UIKit
import WidgetKit

/// View model for iOS clipboard history viewer
@MainActor
class ClipboardHistoryViewModel: ObservableObject {
    @Published var history: [SharedClipboardItem] = []
    @Published var pinnedItems: [SharedClipboardItem] = []
    @Published var isLoading = false
    @Published var lastSyncTime: Date?
    @Published var errorMessage: String?
    @Published var copiedItemID: UUID?
    @Published var savedItemID: UUID?
    @Published var clipboardDetectedText: String?
    @Published var pendingClipboardChangeCount = 0
    @Published var pendingClipboardItemCount = 0

    private let userDefaults = UserDefaults(suiteName: "group.com.saneclip.app")
    /// Track the last clipboard change count to detect new content
    var lastPasteboardChangeCount: Int = 0

    #if ENABLE_SYNC
        private var observationTask: Task<Void, Never>?
        private var automaticSyncTask: Task<Void, Never>?
        private static let automaticSyncInterval: Duration = .seconds(8)
    #endif

    init() {
        loadFromSharedContainer()
        #if ENABLE_SYNC
            startObservingSync()
        #endif
    }

    deinit {
        #if ENABLE_SYNC
            observationTask?.cancel()
            automaticSyncTask?.cancel()
        #endif
    }

    // MARK: - Sync Integration

    #if ENABLE_SYNC
        private func startObservingSync() {
            let coordinator = SyncCoordinator.shared
            mergeFromSync(coordinator)

            observationTask = Task { [weak self] in
                while !Task.isCancelled {
                    // withObservationTracking triggers when syncedItems or lastSyncDate change
                    await withCheckedContinuation { continuation in
                        withObservationTracking {
                            _ = coordinator.syncedItems
                            _ = coordinator.lastSyncDate
                        } onChange: {
                            continuation.resume()
                        }
                    }
                    guard !Task.isCancelled else { break }
                    await MainActor.run { [weak self] in
                        self?.mergeFromSync(coordinator)
                    }
                }
            }
        }

        private func mergeFromSync(_ coordinator: SyncCoordinator) {
            let syncedItems = coordinator.syncedItems
            guard !syncedItems.isEmpty else { return }

            clearDemoDataIfNeeded()

            let existingIDs = Set(history.map(\.id))
            let newItems = syncedItems.filter { !existingIDs.contains($0.id) }

            if !newItems.isEmpty {
                history.append(contentsOf: newItems)
                history.sort { $0.timestamp > $1.timestamp }
                saveToWidgetContainer()
            }

            if let syncDate = coordinator.lastSyncDate {
                lastSyncTime = syncDate
            }
        }

        func beginAutomaticSync() {
            guard automaticSyncTask == nil else { return }

            automaticSyncTask = Task { [weak self] in
                await self?.refreshFromSyncIfEnabled()

                while !Task.isCancelled {
                    do {
                        try await Task.sleep(for: Self.automaticSyncInterval)
                    } catch {
                        break
                    }

                    await self?.refreshFromSyncIfEnabled()
                }
            }
        }

        func endAutomaticSync() {
            automaticSyncTask?.cancel()
            automaticSyncTask = nil
        }

        func refreshFromSyncIfEnabled() async {
            let coordinator = SyncCoordinator.shared
            guard coordinator.isSyncEnabled else { return }

            await coordinator.syncNow()
            mergeFromSync(coordinator)
        }
    #endif

    /// Whether the view model is showing demo data (no real synced data available)
    @Published var isShowingDemoData = false

    /// Load clipboard data from App Group shared container
    func loadFromSharedContainer() {
        if let fullContainer = IOSHistoryDataContainer.load(),
           !fullContainer.recentItems.isEmpty {
            isShowingDemoData = false
            history = fullContainer.recentItems.compactMap(SharedClipboardItem.init(storedItem:))
            pinnedItems = fullContainer.pinnedItems.compactMap(SharedClipboardItem.init(storedItem:))
            lastSyncTime = fullContainer.lastUpdated
            return
        }

        guard let container = WidgetDataContainer.load(),
              !container.recentItems.isEmpty
        else {
            if LaunchOptions.isScreenshotMode() {
                loadDemoDataIfNeeded()
            } else {
                isShowingDemoData = false
                history = []
                pinnedItems = []
            }
            return
        }

        isShowingDemoData = false

        // Convert widget items to shared items for display
        history = container.recentItems.map { widgetItem in
            SharedClipboardItem(
                id: widgetItem.id,
                content: .text(widgetItem.preview),
                timestamp: widgetItem.timestamp,
                sourceAppName: widgetItem.sourceAppName,
                pasteCount: 0,
                deviceId: "",
                deviceName: ""
            )
        }

        pinnedItems = container.pinnedItems.map { widgetItem in
            SharedClipboardItem(
                id: widgetItem.id,
                content: .text(widgetItem.preview),
                timestamp: widgetItem.timestamp,
                sourceAppName: widgetItem.sourceAppName,
                pasteCount: 0,
                deviceId: "",
                deviceName: ""
            )
        }

        lastSyncTime = container.lastUpdated
    }

    /// Provides demo data for App Store screenshots only.
    /// Normal users should see a truthful empty/setup state, not fake clipboard history.
    private func loadDemoDataIfNeeded() {
        // Only show demo data if there's truly nothing
        guard history.isEmpty else { return }

        isShowingDemoData = true

        let now = Date()

        struct DemoItem {
            let text: String
            let app: String?
            let offset: TimeInterval
        }

        let demoItems: [DemoItem] = [
            DemoItem(text: "Can you grab oat milk and pasta on your way home?", app: "Messages", offset: -60),
            DemoItem(text: "Tell mom about SaneBar to manage her menu bar icons.", app: "Messages", offset: -180),
            DemoItem(text: "Your dentist appointment is confirmed for Tuesday at 2:30 PM.", app: "Mail", offset: -420),
            DemoItem(text: "Weekend plan: hike Saturday, meal prep Sunday, call mom.", app: "Notes", offset: -900),
            DemoItem(text: "123 Main St, Tampa, FL 33602", app: "Maps", offset: -1500),
            DemoItem(text: "SaneSales looks clean on iPhone, iPad, and Mac.", app: "Messages", offset: -2400),
            DemoItem(text: "SaneClick is perfect for quick right-click actions.", app: "Messages", offset: -3000),
            DemoItem(text: "Download SaneApps apps later when I'm back at my Mac.", app: "Safari", offset: -3600)
        ]

        history = demoItems.map { demo in
            SharedClipboardItem(
                id: UUID(),
                content: .text(demo.text),
                timestamp: now.addingTimeInterval(demo.offset),
                sourceAppName: demo.app,
                pasteCount: 0,
                deviceId: "demo",
                deviceName: "Demo"
            )
        }

        pinnedItems = [
            SharedClipboardItem(
                id: UUID(),
                content: .text("Mom's birthday checklist: flowers, card, dinner reservation."),
                timestamp: now.addingTimeInterval(-7200),
                sourceAppName: "Reminders",
                pasteCount: 3,
                deviceId: "demo",
                deviceName: "Demo"
            ),
            SharedClipboardItem(
                id: UUID(),
                content: .text("House essentials: trash bags, eggs, coffee beans."),
                timestamp: now.addingTimeInterval(-7800),
                sourceAppName: "Notes",
                pasteCount: 2,
                deviceId: "demo",
                deviceName: "Demo"
            ),
            SharedClipboardItem(
                id: UUID(),
                content: .text("SaneApps download page - save for later."),
                timestamp: now.addingTimeInterval(-8400),
                sourceAppName: "Safari",
                pasteCount: 4,
                deviceId: "demo",
                deviceName: "Demo"
            )
        ]
    }

    func clearDemoDataIfNeeded() {
        guard isShowingDemoData else { return }
        history.removeAll()
        pinnedItems.removeAll()
        isShowingDemoData = false
    }

    /// Persist history to the App Group shared container
    func saveToWidgetContainer() {
        let widgetItems = history.prefix(50).map { item in
            WidgetClipboardItem(
                id: item.id,
                preview: item.preview,
                timestamp: item.timestamp,
                isPinned: pinnedItems.contains { $0.id == item.id },
                sourceAppName: item.sourceAppName,
                contentType: detectContentType(item)
            )
        }

        let pinnedWidgetItems = pinnedItems.map { item in
            WidgetClipboardItem(
                id: item.id,
                preview: item.preview,
                timestamp: item.timestamp,
                isPinned: true,
                sourceAppName: item.sourceAppName,
                contentType: detectContentType(item)
            )
        }

        let container = WidgetDataContainer(
            recentItems: Array(widgetItems),
            pinnedItems: pinnedWidgetItems,
            lastUpdated: Date()
        )

        let fullContainer = IOSHistoryDataContainer(
            recentItems: Array(history.prefix(50)).map(\.storedItem),
            pinnedItems: pinnedItems.map(\.storedItem),
            lastUpdated: container.lastUpdated
        )

        try? container.save()
        try? fullContainer.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func detectContentType(_ item: SharedClipboardItem) -> WidgetClipboardItem.ContentType {
        switch item.content {
        case .text:
            if item.isURL { return .url }
            if item.isCode { return .code }
            return .text
        case .imageData:
            return .image
        }
    }

    /// Delete an item from history
    func deleteItem(_ item: SharedClipboardItem) {
        history.removeAll { $0.id == item.id }
        pinnedItems.removeAll { $0.id == item.id }
        saveToWidgetContainer()

        #if ENABLE_SYNC
            SyncCoordinator.shared.queueDeleteForSync(itemID: item.id)
        #endif
    }

    /// Toggle pin status
    func togglePin(_ item: SharedClipboardItem) {
        if pinnedItems.contains(where: { $0.id == item.id }) {
            pinnedItems.removeAll { $0.id == item.id }
        } else {
            pinnedItems.insert(item, at: 0)
        }
        saveToWidgetContainer()
    }

    /// Check if item is pinned
    func isPinned(_ item: SharedClipboardItem) -> Bool {
        pinnedItems.contains { $0.id == item.id }
    }

    /// Refresh data
    func refresh() async {
        isLoading = true
        errorMessage = nil

        loadFromSharedContainer()

        #if ENABLE_SYNC
            await refreshFromSyncIfEnabled()
        #endif

        isLoading = false
    }

    /// Copy item to iOS clipboard with haptic feedback
    func copyToClipboard(_ item: SharedClipboardItem) {
        switch item.content {
        case let .text(string):
            UIPasteboard.general.string = string
        case let .imageData(data, _, _):
            if let image = UIImage(data: data) {
                UIPasteboard.general.image = image
            }
        }

        markCurrentPasteboardChangeHandled()
        clearPendingClipboardContent()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        copiedItemID = item.id

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if copiedItemID == item.id {
                copiedItemID = nil
            }
        }
    }

    /// Filter history by search text
    func filteredHistory(_ searchText: String) -> [SharedClipboardItem] {
        guard !searchText.isEmpty else { return history }
        return history.filter { item in
            item.preview.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Filter pinned by search text
    func filteredPinned(_ searchText: String) -> [SharedClipboardItem] {
        guard !searchText.isEmpty else { return pinnedItems }
        return pinnedItems.filter { item in
            item.preview.localizedCaseInsensitiveContains(searchText)
        }
    }
}
