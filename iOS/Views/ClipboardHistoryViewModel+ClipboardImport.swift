import SwiftUI
import UIKit

// MARK: - iOS Pasteboard Import

extension ClipboardHistoryViewModel {
    var hasPendingClipboardContent: Bool {
        pendingClipboardItemCount > 0
    }

    var pendingClipboardTitle: String {
        if pendingClipboardItemCount > 1 {
            return "Save \(pendingClipboardItemCount) clipboard items"
        }
        return "Clipboard ready to save"
    }

    var pendingClipboardSubtitle: String {
        let itemLabel = pendingClipboardItemCount == 1 ? "item" : "items"
        #if ENABLE_SYNC
            if SyncCoordinator.shared.isSyncEnabled {
                return "iCloud Sync stays automatic. Tap only to save the current iPhone clipboard."
            }
        #endif

        if pendingClipboardChangeCount > 1 {
            if pendingClipboardItemCount == 1 {
                return "\(pendingClipboardChangeCount) changes detected. iOS can save the latest item."
            }
            return "\(pendingClipboardChangeCount) changes detected. iOS can save the latest \(pendingClipboardItemCount) \(itemLabel)."
        }
        return "Tap to save \(pendingClipboardItemCount) \(itemLabel) from this iPhone."
    }

    /// Save the current iOS clipboard contents to history.
    func saveCurrentClipboard() {
        let pasteboard = UIPasteboard.general
        let savedIDs = saveItemsFromPasteboard(pasteboard)
        lastPasteboardChangeCount = pasteboard.changeCount
        clearPendingClipboardContent()

        guard let savedID = savedIDs.last else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        savedItemID = savedID

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if savedItemID == savedID {
                savedItemID = nil
            }
        }
    }

    /// Check if the clipboard has new content since last check.
    func checkForNewClipboardContent() {
        let pasteboard = UIPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastPasteboardChangeCount else { return }

        let missedChanges = max(1, currentChangeCount - lastPasteboardChangeCount)
        lastPasteboardChangeCount = currentChangeCount

        // Use metadata-only checks so the app can show intent before reading pasteboard content.
        if pasteboard.hasStrings || pasteboard.hasURLs || pasteboard.hasImages {
            pendingClipboardChangeCount = missedChanges
            pendingClipboardItemCount = max(1, pasteboard.numberOfItems)
            clipboardDetectedText = pendingClipboardTitle
        } else {
            clearPendingClipboardContent()
        }
    }

    /// Dismiss the clipboard detection affordance until the pasteboard changes again.
    func dismissClipboardDetection() {
        lastPasteboardChangeCount = UIPasteboard.general.changeCount
        clearPendingClipboardContent()
    }

    func clearPendingClipboardContent() {
        pendingClipboardChangeCount = 0
        pendingClipboardItemCount = 0
        clipboardDetectedText = nil
    }

    func markCurrentPasteboardChangeHandled() {
        lastPasteboardChangeCount = UIPasteboard.general.changeCount

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            self?.lastPasteboardChangeCount = UIPasteboard.general.changeCount
        }
    }

    #if DEBUG
        func forcePendingClipboardCardPreviewIfRequested() {
            guard LaunchOptions.forcePendingClipboardCardPreview() else { return }

            pendingClipboardChangeCount = 2
            pendingClipboardItemCount = 2
            clipboardDetectedText = pendingClipboardTitle
        }
    #endif

    @discardableResult
    private func saveItemsFromPasteboard(_ pasteboard: UIPasteboard) -> [UUID] {
        let importedItems = sharedClipboardItems(from: pasteboard)
        guard !importedItems.isEmpty else { return [] }

        clearDemoDataIfNeeded()

        var savedIDs: [UUID] = []
        for item in importedItems.reversed() where insertClipboardItem(item) {
            savedIDs.append(item.id)

            #if ENABLE_SYNC
                SyncCoordinator.shared.queueItemForSync(item)
            #endif
        }

        guard !savedIDs.isEmpty else { return [] }

        isShowingDemoData = false
        saveToWidgetContainer()
        return savedIDs
    }

    private func insertClipboardItem(_ item: SharedClipboardItem) -> Bool {
        switch item.content {
        case let .text(text):
            if let first = history.first, first.fullText == text {
                return false
            }
            history.removeAll { $0.fullText == text }
        case let .imageData(data, _, _):
            history.removeAll { existing in
                guard case let .imageData(existingData, _, _) = existing.content else { return false }
                return existingData == data
            }
        }

        history.insert(item, at: 0)
        return true
    }

    private func sharedClipboardItems(from pasteboard: UIPasteboard) -> [SharedClipboardItem] {
        let itemDictionaries = pasteboard.items
        var items: [SharedClipboardItem] = []
        var seenTexts = Set<String>()
        var seenImages = Set<Data>()

        for itemDictionary in itemDictionaries {
            if let text = textContent(in: itemDictionary),
               shouldSaveTextContent(text),
               seenTexts.insert(text).inserted {
                items.append(makeTextItem(text))
            } else if let image = imageContent(in: itemDictionary),
                      seenImages.insert(image.data).inserted {
                items.append(makeImageItem(data: image.data, width: image.width, height: image.height))
            }
        }

        appendFallbackItems(from: pasteboard, to: &items, seenTexts: &seenTexts, seenImages: &seenImages)

        return items
    }

    private func appendFallbackItems(
        from pasteboard: UIPasteboard,
        to items: inout [SharedClipboardItem],
        seenTexts: inout Set<String>,
        seenImages: inout Set<Data>
    ) {
        for text in pasteboard.strings ?? [] {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  shouldSaveTextContent(trimmed),
                  seenTexts.insert(trimmed).inserted else { continue }
            items.append(makeTextItem(trimmed))
        }

        for url in pasteboard.urls ?? [] {
            let text = url.absoluteString
            guard shouldSaveTextContent(text),
                  seenTexts.insert(text).inserted else { continue }
            items.append(makeTextItem(text))
        }

        for image in pasteboard.images ?? [] {
            guard let data = image.pngData(), seenImages.insert(data).inserted else { continue }
            items.append(makeImageItem(data: data, width: Int(image.size.width), height: Int(image.size.height)))
        }
    }

    private func makeTextItem(_ text: String) -> SharedClipboardItem {
        SharedClipboardItem(
            id: UUID(),
            content: .text(text),
            timestamp: Date(),
            sourceAppName: "Clipboard",
            pasteCount: 0,
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "ios",
            deviceName: UIDevice.current.name
        )
    }

    private func makeImageItem(data: Data, width: Int, height: Int) -> SharedClipboardItem {
        SharedClipboardItem(
            id: UUID(),
            content: .imageData(data, width: width, height: height),
            timestamp: Date(),
            sourceAppName: "Clipboard",
            pasteCount: 0,
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "ios",
            deviceName: UIDevice.current.name
        )
    }

    private func shouldSaveTextContent(_ text: String) -> Bool {
        !SensitiveDataDetector.shared.containsHighRiskSensitiveData(in: text)
    }

    private func textContent(in item: [String: Any]) -> String? {
        for type in Self.textPasteboardTypes {
            if let text = stringValue(from: item[type]) {
                return text
            }
        }

        for (type, value) in item where type.localizedCaseInsensitiveContains("text") || type.localizedCaseInsensitiveContains("url") {
            if let text = stringValue(from: value) {
                return text
            }
        }

        return nil
    }

    private func stringValue(from value: Any?) -> String? {
        let rawText: String? = switch value {
        case let text as String:
            text
        case let text as NSString:
            text as String
        case let url as URL:
            url.absoluteString
        case let data as Data:
            String(data: data, encoding: .utf8)
        default:
            nil
        }

        let trimmed = rawText?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func imageContent(in item: [String: Any]) -> ImportedImage? {
        for (type, value) in item where type.localizedCaseInsensitiveContains("image") {
            if let image = imageValue(from: value) {
                return image
            }
        }

        for value in item.values {
            if let image = imageValue(from: value) {
                return image
            }
        }

        return nil
    }

    private func imageValue(from value: Any) -> ImportedImage? {
        if let image = value as? UIImage,
           let data = image.pngData() {
            return ImportedImage(data: data, width: Int(image.size.width), height: Int(image.size.height))
        }

        if let data = value as? Data,
           let image = UIImage(data: data) {
            return ImportedImage(data: data, width: Int(image.size.width), height: Int(image.size.height))
        }

        return nil
    }

    private static let textPasteboardTypes = [
        "public.utf8-plain-text",
        "public.plain-text",
        "public.text",
        "public.url",
        "public.file-url"
    ]

    private struct ImportedImage {
        let data: Data
        let width: Int
        let height: Int
    }
}
