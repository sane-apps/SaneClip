import AppKit
import SwiftUI

enum ClipboardContent {
    case text(String)
    case image(NSImage)
}

struct ClipboardItem: Identifiable {
    let id: UUID
    let content: ClipboardContent
    let timestamp: Date
    let sourceAppBundleID: String?
    let sourceAppName: String?
    var pasteCount: Int

    init(
        id: UUID = UUID(),
        content: ClipboardContent,
        timestamp: Date = Date(),
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        pasteCount: Int = 0
    ) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.pasteCount = pasteCount
    }

    /// Get the app icon for the source app
    var sourceAppIcon: NSImage? {
        guard let bundleID = sourceAppBundleID,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }

    var contentHash: String {
        switch content {
        case .text(let string):
            return "text:\(string.hashValue)"
        case .image(let image):
            return "image:\(image.tiffRepresentation?.hashValue ?? 0)"
        }
    }

    var preview: String {
        switch content {
        case .text(let string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 100 {
                return String(trimmed.prefix(100)) + "..."
            }
            return trimmed
        case .image:
            return "[Image]"
        }
    }

    var stats: String {
        switch content {
        case .text(let string):
            let words = string.split { $0.isWhitespace || $0.isNewline }.count
            let chars = string.count
            return "\(words)wd · \(chars)ch"
        case .image(let image):
            let size = image.size
            return "\(Int(size.width))×\(Int(size.height))"
        }
    }

    /// Simple heuristic to detect if content is code
    var isCode: Bool {
        guard case .text(let string) = content else { return false }
        let codeIndicators = [
            "func ", "var ", "let ", "import ", "class ", "struct ",
            "def ", "package ", "{", "}", ";", "=>", "return"
        ]
        let lines = string.components(separatedBy: .newlines)

        // If it's multi-line and contains indicators
        if lines.count > 1 {
            let matches = codeIndicators.filter { string.contains($0) }.count
            return matches >= 2
        }

        // Single line code often has specific chars
        return string.contains(";") || string.contains("{") || string.contains("()")
    }

    /// Detect if content is a URL
    var isURL: Bool {
        guard case .text(let string) = content else { return false }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.hasPrefix("www.")
    }

    /// Strip tracking parameters from URL (utm_*, fbclid, gclid, etc.)
    static func stripTrackingParams(from urlString: String) -> String {
        guard var components = URLComponents(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return urlString
        }

        let trackingPrefixes = [
            "utm_", "fbclid", "gclid", "ref_", "mc_",
            "yclid", "msclkid", "_ga", "_gl", "igshid", "s_kwcid"
        ]

        components.queryItems = components.queryItems?.filter { item in
            !trackingPrefixes.contains(where: { item.name.lowercased().hasPrefix($0) || item.name.lowercased() == $0 })
        }

        // Remove empty query string
        if components.queryItems?.isEmpty == true {
            components.queryItems = nil
        }

        return components.string ?? urlString
    }

    /// Compact time ago string with smart scaling
    var timeAgo: String {
        let seconds = Int(-timestamp.timeIntervalSinceNow)
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h"
        }
        let days = hours / 24
        return "\(days)d"
    }
}
