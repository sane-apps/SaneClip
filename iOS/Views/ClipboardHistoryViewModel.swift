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

    private let userDefaults = UserDefaults(suiteName: "group.com.saneclip.app")
    /// Track the last clipboard change count to detect new content
    private var lastPasteboardChangeCount: Int = 0

    #if ENABLE_SYNC
        private var observationTask: Task<Void, Never>?
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

            let existingIDs = Set(history.map(\.id))
            let newItems = syncedItems.filter { !existingIDs.contains($0.id) }

            if !newItems.isEmpty {
                history.append(contentsOf: newItems)
                history.sort { $0.timestamp > $1.timestamp }
            }

            if let syncDate = coordinator.lastSyncDate {
                lastSyncTime = syncDate
            }
        }
    #endif

    /// Whether the view model is showing demo data (no real synced data available)
    @Published var isShowingDemoData = false

    /// Load clipboard data from App Group shared container
    func loadFromSharedContainer() {
        guard let container = WidgetDataContainer.load(),
              !container.recentItems.isEmpty
        else {
            // No synced data yet — load demo data so reviewers can see the app working
            loadDemoDataIfNeeded()
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

    /// Provides demo data so reviewers (and new users) can see the app working
    /// even before the Mac app has synced any clipboard history.
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
            DemoItem(text: "https://developer.apple.com/documentation/swiftui", app: "Safari", offset: -60),
            DemoItem(text: "Meeting notes: Discussed Q1 roadmap and feature priorities for the next release.", app: "Notes", offset: -300),
            DemoItem(text: "func greet(name: String) -> String {\n    return \"Hello, \\(name)!\"\n}", app: "Xcode", offset: -900),
            DemoItem(text: "The quick brown fox jumps over the lazy dog.", app: "TextEdit", offset: -1800),
            DemoItem(text: "support@example.com", app: "Mail", offset: -3600)
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
                content: .text("My frequently used snippet — pinned for quick access"),
                timestamp: now.addingTimeInterval(-7200),
                sourceAppName: "Notes",
                pasteCount: 3,
                deviceId: "demo",
                deviceName: "Demo"
            )
        ]
    }

    // MARK: - Save Clipboard

    /// Save the current iOS clipboard contents to history
    func saveCurrentClipboard() {
        let pasteboard = UIPasteboard.general

        if let text = pasteboard.string, !text.isEmpty {
            saveItem(text: text, sourceApp: "Clipboard")
        } else if let url = pasteboard.url {
            saveItem(text: url.absoluteString, sourceApp: "Clipboard")
        } else if let image = pasteboard.image, let data = image.pngData() {
            saveImageItem(data: data, width: Int(image.size.width), height: Int(image.size.height))
        } else {
            // Nothing on clipboard
            return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func saveItem(text: String, sourceApp: String) {
        // Don't add duplicates at the top
        if let first = history.first, first.fullText == text {
            return
        }

        let newItem = SharedClipboardItem(
            id: UUID(),
            content: .text(text),
            timestamp: Date(),
            sourceAppName: sourceApp,
            pasteCount: 0,
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "ios",
            deviceName: UIDevice.current.name
        )

        // Remove existing duplicate if present
        history.removeAll { $0.fullText == text }
        history.insert(newItem, at: 0)

        // Clear demo data flag
        isShowingDemoData = false

        saveToWidgetContainer()
        savedItemID = newItem.id

        #if ENABLE_SYNC
            SyncCoordinator.shared.queueItemForSync(newItem)
        #endif

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if savedItemID == newItem.id {
                savedItemID = nil
            }
        }
    }

    private func saveImageItem(data: Data, width: Int, height: Int) {
        let newItem = SharedClipboardItem(
            id: UUID(),
            content: .imageData(data, width: width, height: height),
            timestamp: Date(),
            sourceAppName: "Clipboard",
            pasteCount: 0,
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "ios",
            deviceName: UIDevice.current.name
        )

        history.insert(newItem, at: 0)
        isShowingDemoData = false
        saveToWidgetContainer()
        savedItemID = newItem.id

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if savedItemID == newItem.id {
                savedItemID = nil
            }
        }
    }

    /// Check if the clipboard has new content since last check
    func checkForNewClipboardContent() {
        let pasteboard = UIPasteboard.general
        guard pasteboard.changeCount != lastPasteboardChangeCount else { return }
        lastPasteboardChangeCount = pasteboard.changeCount

        // Use hasStrings/hasURLs/hasImages to detect without triggering paste banner
        if pasteboard.hasStrings || pasteboard.hasURLs || pasteboard.hasImages {
            clipboardDetectedText = "New clipboard content detected"
        }
    }

    /// Dismiss the clipboard detection banner
    func dismissClipboardDetection() {
        clipboardDetectedText = nil
    }

    /// Persist history to the App Group shared container
    private func saveToWidgetContainer() {
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

        try? container.save()
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
            mergeFromSync(SyncCoordinator.shared)
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
