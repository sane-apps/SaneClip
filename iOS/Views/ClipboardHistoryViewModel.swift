import SwiftUI
import UIKit

/// View model for iOS clipboard history viewer
@MainActor
class ClipboardHistoryViewModel: ObservableObject {
    @Published var history: [SharedClipboardItem] = []
    @Published var pinnedItems: [SharedClipboardItem] = []
    @Published var isLoading = false
    @Published var lastSyncTime: Date?
    @Published var errorMessage: String?
    @Published var copiedItemID: UUID?

    private let userDefaults = UserDefaults(suiteName: "group.com.saneclip.app")

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

    /// Load clipboard data from App Group shared container
    func loadFromSharedContainer() {
        guard let container = WidgetDataContainer.load() else {
            // No data yet - show empty state
            return
        }

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
