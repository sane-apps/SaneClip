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
