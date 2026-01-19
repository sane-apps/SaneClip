import Testing
@testable import SaneClip

struct SaneClipTests {
    @Test("ClipboardItem preview truncates long text")
    func clipboardItemPreviewTruncation() {
        let longText = String(repeating: "a", count: 200)
        let item = ClipboardItem(content: .text(longText))

        #expect(item.preview.count == 103) // 100 chars + "..."
        #expect(item.preview.hasSuffix("..."))
    }

    @Test("ClipboardItem preview returns full short text")
    func clipboardItemPreviewShortText() {
        let shortText = "Hello, World!"
        let item = ClipboardItem(content: .text(shortText))

        #expect(item.preview == shortText)
    }

    @Test("ClipboardItem content hash is consistent")
    func clipboardItemContentHash() {
        let text = "Test content"
        let item1 = ClipboardItem(content: .text(text))
        let item2 = ClipboardItem(content: .text(text))

        #expect(item1.contentHash == item2.contentHash)
    }

    @Test("ClipboardItem stores source app info")
    func clipboardItemSourceApp() {
        let item = ClipboardItem(
            content: .text("Test"),
            sourceAppBundleID: "com.apple.Safari",
            sourceAppName: "Safari"
        )

        #expect(item.sourceAppBundleID == "com.apple.Safari")
        #expect(item.sourceAppName == "Safari")
    }

    @Test("ClipboardItem source app info is optional")
    func clipboardItemSourceAppOptional() {
        let item = ClipboardItem(content: .text("Test"))

        #expect(item.sourceAppBundleID == nil)
        #expect(item.sourceAppName == nil)
    }

    @Test("SettingsModel excludes apps correctly")
    @MainActor
    func settingsModelExcludedApps() {
        let settings = SettingsModel.shared

        // Save original state
        let originalExcluded = settings.excludedApps

        // Test excluding an app
        settings.excludedApps = ["com.test.app"]
        #expect(settings.isAppExcluded("com.test.app") == true)
        #expect(settings.isAppExcluded("com.other.app") == false)
        #expect(settings.isAppExcluded(nil) == false)

        // Restore original state
        settings.excludedApps = originalExcluded
    }

    @Test("URL tracking parameters are stripped")
    func urlTrackingParamsStripped() {
        let urlWithTracking = "https://example.com/page?utm_source=newsletter&utm_medium=email&real_param=keep&fbclid=abc123"
        let cleaned = ClipboardItem.stripTrackingParams(from: urlWithTracking)
        
        #expect(cleaned == "https://example.com/page?real_param=keep")
        #expect(!cleaned.contains("utm_"))
        #expect(!cleaned.contains("fbclid"))
    }

    @Test("Clean URL remains unchanged")
    func cleanUrlUnchanged() {
        let cleanUrl = "https://example.com/page?id=123&name=test"
        let result = ClipboardItem.stripTrackingParams(from: cleanUrl)
        
        #expect(result == cleanUrl)
    }
}
