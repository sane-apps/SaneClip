import AppKit

/// Process-wide cache of source-app icons keyed by bundle identifier.
///
/// `ClipboardItem.sourceAppIcon` is read once per visible history row on every
/// render/scroll frame, and each miss did two `NSWorkspace` lookups
/// (`urlForApplication` + `icon(forFile:)`). A history references only a handful
/// of distinct apps, so caching turns that into one lookup per app. `NSCache` is
/// thread-safe and self-evicts under memory pressure, so a stale icon simply
/// re-resolves on the next read.
enum SourceAppIconCache {
    private static let cache = NSCache<NSString, NSImage>()

    /// The cached icon for `bundleID`, resolving and caching it on first use.
    /// Returns `nil` if the app can't be located (e.g. it was uninstalled).
    static func icon(forBundleID bundleID: String) -> NSImage? {
        let key = bundleID as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        cache.setObject(icon, forKey: key)
        return icon
    }
}
