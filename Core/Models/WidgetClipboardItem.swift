import Foundation

/// Lightweight clipboard item model for widget display
/// Shared between main app and widget extension via App Group container
struct WidgetClipboardItem: Codable, Identifiable {
    let id: UUID
    let preview: String
    let timestamp: Date
    let isPinned: Bool
    let sourceAppName: String?
    let contentType: ContentType

    enum ContentType: String, Codable {
        case text
        case url
        case code
        case image
    }

    /// Relative timestamp for display (e.g., "2h ago")
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    /// Truncated preview for widget display
    func truncatedPreview(maxLength: Int = 50) -> String {
        if preview.count <= maxLength {
            return preview
        }
        return String(preview.prefix(maxLength - 3)) + "..."
    }
}

/// Container for widget data stored in App Group
struct WidgetDataContainer: Codable {
    let recentItems: [WidgetClipboardItem]
    let pinnedItems: [WidgetClipboardItem]
    let lastUpdated: Date

    static let fileName = "widget-data.json"

    /// URL for shared container
    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.saneclip.app"
        )
    }

    /// Full path to widget data file
    static var fileURL: URL? {
        sharedContainerURL?.appendingPathComponent(fileName)
    }

    /// Load widget data from shared container
    static func load() -> WidgetDataContainer? {
        guard let url = fileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(WidgetDataContainer.self, from: data)
        } catch {
            return nil
        }
    }

    /// Save widget data to shared container
    func save() throws {
        guard let url = WidgetDataContainer.fileURL else {
            throw WidgetDataError.noSharedContainer
        }
        let data = try JSONEncoder().encode(self)
        try data.write(to: url)
    }
}

enum WidgetDataError: Error {
    case noSharedContainer
}

/// Full-fidelity iOS clipboard persistence for the app + share extension.
/// Kept separate from widget-data.json so widgets don't pay to decode raw clip payloads.
struct IOSHistoryDataContainer: Codable {
    let recentItems: [StoredClipboardItem]
    let pinnedItems: [StoredClipboardItem]
    let lastUpdated: Date

    static let fileName = "ios-history.json"

    static var sharedContainerURL: URL? {
        WidgetDataContainer.sharedContainerURL
    }

    static var fileURL: URL? {
        sharedContainerURL?.appendingPathComponent(fileName)
    }

    static func load() -> IOSHistoryDataContainer? {
        guard let url = fileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(IOSHistoryDataContainer.self, from: data)
        } catch {
            return nil
        }
    }

    func save() throws {
        guard let url = IOSHistoryDataContainer.fileURL else {
            throw WidgetDataError.noSharedContainer
        }
        let data = try JSONEncoder().encode(self)
        try data.write(to: url)
    }
}

struct StoredClipboardItem: Codable, Identifiable {
    enum ContentKind: String, Codable {
        case text
        case image
    }

    let id: UUID
    let contentKind: ContentKind
    let text: String?
    let imageData: Data?
    let imageWidth: Int?
    let imageHeight: Int?
    let timestamp: Date
    let sourceAppBundleID: String?
    let sourceAppName: String?
    let pasteCount: Int
    let note: String?
    let deviceId: String
    let deviceName: String
}
