import Foundation

/// Chooses widget rows. Sample text is only for the widget gallery preview.
enum WidgetTimelineSelection {
    static func items<T>(
        stored: [T]?,
        limit: Int,
        isPreview: Bool,
        samples: [T]
    ) -> [T] {
        let cappedLimit = max(0, limit)
        if isPreview {
            return Array(samples.prefix(cappedLimit))
        }
        guard let stored else { return [] }
        return Array(stored.prefix(cappedLimit))
    }
}

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

/// Ids saved on this phone that still need one upload.
/// Existing history is not backfilled, so a clip the Mac already deleted stays deleted.
enum PendingSyncUploadIDs {
    static let key = "pendingSyncUploadItemIDs"

    static func adding(_ itemID: UUID, to existing: [String], limit: Int = 400) -> [String] {
        var stored = existing
        let id = itemID.uuidString
        stored.removeAll { $0 == id }
        stored.append(id)
        let cappedLimit = max(1, limit)
        if stored.count > cappedLimit {
            stored.removeFirst(stored.count - cappedLimit)
        }
        return stored
    }

    static func removing(_ itemID: UUID, from existing: [String]) -> [String] {
        let id = itemID.uuidString
        return existing.filter { $0 != id }
    }

    static func mark(
        _ itemID: UUID,
        defaults: UserDefaults? = UserDefaults(suiteName: SharedClipboardCachePrivacy.appGroupSuiteName)
    ) {
        guard let defaults else { return }
        let existing = defaults.stringArray(forKey: key) ?? []
        defaults.set(adding(itemID, to: existing), forKey: key)
    }

    static func clear(
        _ itemID: UUID,
        defaults: UserDefaults? = UserDefaults(suiteName: SharedClipboardCachePrivacy.appGroupSuiteName)
    ) {
        guard let defaults else { return }
        let existing = defaults.stringArray(forKey: key) ?? []
        defaults.set(removing(itemID, from: existing), forKey: key)
    }

    static func ids(
        defaults: UserDefaults? = UserDefaults(suiteName: SharedClipboardCachePrivacy.appGroupSuiteName)
    ) -> Set<UUID> {
        Set((defaults?.stringArray(forKey: key) ?? []).compactMap(UUID.init(uuidString:)))
    }
}

enum SharedClipboardCachePrivacy {
    static let appGroupSuiteName = "group.com.saneclip.app"
    static let encryptHistoryKey = "encryptHistory"

    static func shouldWithholdPlaintextCaches(
        defaults: UserDefaults = .standard,
        sharedDefaults: UserDefaults? = UserDefaults(suiteName: appGroupSuiteName)
    ) -> Bool {
        let standardSetting = defaults.object(forKey: encryptHistoryKey) as? Bool ?? false
        let sharedSetting = sharedDefaults?.object(forKey: encryptHistoryKey) as? Bool ?? false
        return standardSetting || sharedSetting
    }

    static func clearPlaintextCaches(lastUpdated: Date = Date()) throws {
        try WidgetDataContainer(recentItems: [], pinnedItems: [], lastUpdated: lastUpdated).save()
        try IOSHistoryDataContainer(recentItems: [], pinnedItems: [], lastUpdated: lastUpdated).save()
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
