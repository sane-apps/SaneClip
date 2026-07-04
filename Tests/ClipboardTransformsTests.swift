import AppKit
@testable import SaneClip
import Testing

/// Tests for the content transforms and caches added in the Maccy easy-wins
/// pass: widened tracking-param stripping (#1413), the strip-trailing-newline
/// rule (#1044), and the source-app icon cache (#1416).
struct ClipboardTransformsTests {
    // MARK: - #1413 widened tracking-param stripping

    @Test("Widened tracking-param list strips newer ad params but keeps real query")
    func stripsWidenedTrackingParams() {
        let url = "https://shop.example.com/p?id=42&mkt_tok=ABC&gbraid=XYZ&twclid=99&utm_source=news"
        let cleaned = ClipboardItem.stripTrackingParams(from: url)
        #expect(cleaned.contains("id=42"))
        #expect(!cleaned.contains("mkt_tok"))
        #expect(!cleaned.contains("gbraid"))
        #expect(!cleaned.contains("twclid"))
        #expect(!cleaned.contains("utm_source"))
    }

    @Test("Tracking strip leaves a param-free URL untouched")
    func leavesCleanURLUntouched() {
        let url = "https://example.com/path"
        #expect(ClipboardItem.stripTrackingParams(from: url) == url)
    }

    // MARK: - #1044 strip trailing newline

    @Test("Strip-trailing-newline rule drops only trailing newlines")
    @MainActor
    func stripsOnlyTrailingNewlines() {
        let rules = ClipboardRulesManager.shared
        // Snapshot every rule, isolate to just this one, and restore after so the
        // shared UserDefaults-backed singleton can't leak state into other tests.
        let snapshot = (
            rules.stripTrailingNewline, rules.autoTrimWhitespace, rules.normalizeLineEndings,
            rules.removeDuplicateSpaces, rules.stripTrackingParams, rules.lowercaseURLs
        )
        defer {
            rules.stripTrailingNewline = snapshot.0
            rules.autoTrimWhitespace = snapshot.1
            rules.normalizeLineEndings = snapshot.2
            rules.removeDuplicateSpaces = snapshot.3
            rules.stripTrackingParams = snapshot.4
            rules.lowercaseURLs = snapshot.5
        }
        rules.autoTrimWhitespace = false
        rules.normalizeLineEndings = false
        rules.removeDuplicateSpaces = false
        rules.stripTrackingParams = false
        rules.lowercaseURLs = false

        rules.stripTrailingNewline = true
        #expect(rules.process("git status\n") == "git status")
        #expect(rules.process("git status\n\n\n") == "git status")
        // Leading indentation and internal newlines are preserved.
        #expect(rules.process("  line1\nline2\n") == "  line1\nline2")

        rules.stripTrailingNewline = false
        #expect(rules.process("git status\n") == "git status\n")
    }

    // MARK: - #1416 source-app icon cache

    @Test("Source-app icon cache returns a cached instance and nil for unknown apps")
    func iconCacheCachesAndHandlesMissing() {
        let first = SourceAppIconCache.icon(forBundleID: "com.apple.finder")
        #expect(first != nil)
        let second = SourceAppIconCache.icon(forBundleID: "com.apple.finder")
        #expect(first === second) // served from cache, same object identity
        #expect(SourceAppIconCache.icon(forBundleID: "com.saneapps.nonexistent.zzz") == nil)
    }
}
