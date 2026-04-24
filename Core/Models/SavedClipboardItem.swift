import Foundation

struct SavedClipboardItem: Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let sourceAppBundleID: String?
    let sourceAppName: String?
    let pasteCount: Int
    let title: String?
    let tags: [String]
    let collection: String
    let note: String?
    /// Filename of the downsized thumbnail in the thumbnails directory (image items only)
    let imageThumbnailFilename: String?
    /// Filename of the original image data in the images directory (image items only)
    let imageDataFilename: String?
    /// OCR text recognized from image items, stored locally for search and copy-text actions.
    let ocrText: String?

    init(
        id: UUID,
        text: String,
        timestamp: Date,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        pasteCount: Int = 0,
        title: String? = nil,
        tags: [String] = [],
        collection: String = "Default",
        note: String? = nil,
        imageThumbnailFilename: String? = nil,
        imageDataFilename: String? = nil,
        ocrText: String? = nil
    ) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.pasteCount = pasteCount
        self.title = title
        self.tags = tags
        self.collection = collection
        self.note = note
        self.imageThumbnailFilename = imageThumbnailFilename
        self.imageDataFilename = imageDataFilename
        self.ocrText = ocrText
    }

    // Custom decoder for backward compatibility with old history files
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        sourceAppBundleID = try container.decodeIfPresent(String.self, forKey: .sourceAppBundleID)
        sourceAppName = try container.decodeIfPresent(String.self, forKey: .sourceAppName)
        pasteCount = try container.decodeIfPresent(Int.self, forKey: .pasteCount) ?? 0
        title = try container.decodeIfPresent(String.self, forKey: .title)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        collection = try container.decodeIfPresent(String.self, forKey: .collection) ?? "Default"
        note = try container.decodeIfPresent(String.self, forKey: .note)
        imageThumbnailFilename = try container.decodeIfPresent(String.self, forKey: .imageThumbnailFilename)
        imageDataFilename = try container.decodeIfPresent(String.self, forKey: .imageDataFilename)
        ocrText = try container.decodeIfPresent(String.self, forKey: .ocrText)
    }
}
