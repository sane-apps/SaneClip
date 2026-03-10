import Social
import UIKit
import UniformTypeIdentifiers

/// Share Extension that receives content from other apps and saves to SaneClip's shared container
class ShareViewController: SLComposeServiceViewController {
    override func isContentValid() -> Bool {
        // Accept any content that has text
        !contentText.isEmpty || hasAttachments
    }

    override func didSelectPost() {
        saveSharedContent()
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        []
    }

    // MARK: - Save to Shared Container

    private var hasAttachments: Bool {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return false }
        return items.contains { item in
            item.attachments?.contains { provider in
                provider.hasItemConformingToTypeIdentifier(UTType.url.identifier)
                    || provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
            } ?? false
        }
    }

    private func saveSharedContent() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return }

        for item in items {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] data, _ in
                        if let url = data as? URL {
                            self?.addToHistory(text: url.absoluteString, type: .url)
                        } else if let urlData = data as? Data, let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                            self?.addToHistory(text: url.absoluteString, type: .url)
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] data, _ in
                        if let text = data as? String {
                            self?.addToHistory(text: text, type: .text)
                        }
                    }
                }
            }
        }

        // Also capture the compose text if any
        if let text = contentText, !text.isEmpty {
            addToHistory(text: text, type: .text)
        }
    }

    private func addToHistory(text: String, type: WidgetClipboardItem.ContentType) {
        let now = Date()
        let widgetItem = WidgetClipboardItem(
            id: UUID(),
            preview: String(text.prefix(200)),
            timestamp: now,
            isPinned: false,
            sourceAppName: "Shared",
            contentType: type
        )
        let storedItem = StoredClipboardItem(
            id: widgetItem.id,
            contentKind: .text,
            text: text,
            imageData: nil,
            imageWidth: nil,
            imageHeight: nil,
            timestamp: now,
            sourceAppBundleID: nil,
            sourceAppName: "Shared",
            pasteCount: 0,
            note: nil,
            deviceId: "ios-share",
            deviceName: UIDevice.current.name
        )

        var widgetContainer = WidgetDataContainer.load() ?? WidgetDataContainer(
            recentItems: [],
            pinnedItems: [],
            lastUpdated: now
        )
        var fullContainer = IOSHistoryDataContainer.load() ?? IOSHistoryDataContainer(
            recentItems: [],
            pinnedItems: [],
            lastUpdated: now
        )

        var recentWidgetItems = widgetContainer.recentItems
        recentWidgetItems.removeAll { $0.preview == widgetItem.preview }
        recentWidgetItems.insert(widgetItem, at: 0)
        if recentWidgetItems.count > 50 {
            recentWidgetItems = Array(recentWidgetItems.prefix(50))
        }

        var recentStoredItems = fullContainer.recentItems
        recentStoredItems.removeAll { $0.text == text }
        recentStoredItems.insert(storedItem, at: 0)
        if recentStoredItems.count > 50 {
            recentStoredItems = Array(recentStoredItems.prefix(50))
        }

        widgetContainer = WidgetDataContainer(
            recentItems: recentWidgetItems,
            pinnedItems: widgetContainer.pinnedItems,
            lastUpdated: now
        )
        fullContainer = IOSHistoryDataContainer(
            recentItems: recentStoredItems,
            pinnedItems: fullContainer.pinnedItems,
            lastUpdated: now
        )

        try? widgetContainer.save()
        try? fullContainer.save()
    }
}
