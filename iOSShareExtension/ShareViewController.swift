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
        saveSharedContent { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
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

    private func saveSharedContent(completion: @escaping () -> Void) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion()
            return
        }

        let group = DispatchGroup()

        for item in items {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] data, _ in
                        let sharedURL: String?
                        if let url = data as? URL {
                            sharedURL = url.absoluteString
                        } else if let urlData = data as? Data, let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                            sharedURL = url.absoluteString
                        } else {
                            sharedURL = nil
                        }

                        DispatchQueue.main.async {
                            if let sharedURL {
                                self?.addToHistory(text: sharedURL, type: .url)
                            }
                            group.leave()
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] data, _ in
                        let sharedText = data as? String
                        DispatchQueue.main.async {
                            if let sharedText {
                                self?.addToHistory(text: sharedText, type: .text)
                            }
                            group.leave()
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
                        let importedImage: ImportedShareImage?
                        if let image = data as? UIImage,
                           let imageData = image.pngData() {
                            importedImage = ImportedShareImage(data: imageData, width: Int(image.size.width), height: Int(image.size.height))
                        } else if let imageURL = data as? URL,
                                  let imageData = try? Data(contentsOf: imageURL),
                                  let image = UIImage(data: imageData) {
                            importedImage = ImportedShareImage(data: imageData, width: Int(image.size.width), height: Int(image.size.height))
                        } else if let imageData = data as? Data,
                                  let image = UIImage(data: imageData) {
                            importedImage = ImportedShareImage(data: imageData, width: Int(image.size.width), height: Int(image.size.height))
                        } else {
                            importedImage = nil
                        }

                        DispatchQueue.main.async {
                            if let importedImage {
                                self?.addImageToHistory(
                                    data: importedImage.data,
                                    width: importedImage.width,
                                    height: importedImage.height
                                )
                            }
                            group.leave()
                        }
                    }
                }
            }
        }

        // Also capture the compose text if any
        if let text = contentText, !text.isEmpty {
            addToHistory(text: text, type: .text)
        }

        group.notify(queue: .main, execute: completion)
    }

    private func addToHistory(text: String, type: WidgetClipboardItem.ContentType) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !SensitiveDataDetector.shared.containsHighRiskSensitiveData(in: trimmed) else { return }

        let now = Date()
        let widgetItem = WidgetClipboardItem(
            id: UUID(),
            preview: String(trimmed.prefix(200)),
            timestamp: now,
            isPinned: false,
            sourceAppName: "Shared",
            contentType: type
        )
        let storedItem = StoredClipboardItem(
            id: widgetItem.id,
            contentKind: .text,
            text: trimmed,
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
        recentStoredItems.removeAll { $0.text == trimmed }
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

    private func addImageToHistory(data: Data, width: Int, height: Int) {
        let now = Date()
        let id = UUID()
        let widgetItem = WidgetClipboardItem(
            id: id,
            preview: "[Image]",
            timestamp: now,
            isPinned: false,
            sourceAppName: "Shared",
            contentType: .image
        )
        let storedItem = StoredClipboardItem(
            id: id,
            contentKind: .image,
            text: nil,
            imageData: data,
            imageWidth: width,
            imageHeight: height,
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
        recentWidgetItems.insert(widgetItem, at: 0)
        if recentWidgetItems.count > 50 {
            recentWidgetItems = Array(recentWidgetItems.prefix(50))
        }

        var recentStoredItems = fullContainer.recentItems
        recentStoredItems.removeAll { $0.imageData == data }
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

    private struct ImportedShareImage {
        let data: Data
        let width: Int
        let height: Int
    }
}
