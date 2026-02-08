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
        guard var container = WidgetDataContainer.load() else {
            // Create new container with just this item
            let item = WidgetClipboardItem(
                id: UUID(),
                preview: String(text.prefix(200)),
                timestamp: Date(),
                isPinned: false,
                sourceAppName: "Shared",
                contentType: type
            )
            let newContainer = WidgetDataContainer(
                recentItems: [item],
                pinnedItems: [],
                lastUpdated: Date()
            )
            try? newContainer.save()
            return
        }

        let newItem = WidgetClipboardItem(
            id: UUID(),
            preview: String(text.prefix(200)),
            timestamp: Date(),
            isPinned: false,
            sourceAppName: "Shared",
            contentType: type
        )

        // Prepend new item, keep max 50
        var recent = container.recentItems
        // Deduplicate - remove if same text already exists
        recent.removeAll { $0.preview == newItem.preview }
        recent.insert(newItem, at: 0)
        if recent.count > 50 {
            recent = Array(recent.prefix(50))
        }

        let updated = WidgetDataContainer(
            recentItems: recent,
            pinnedItems: container.pinnedItems,
            lastUpdated: Date()
        )
        try? updated.save()
    }
}
