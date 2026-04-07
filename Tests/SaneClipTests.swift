import AppKit
import CloudKit
#if !APP_STORE
    import Sparkle
#endif
import SaneUI
import SwiftUI
import Testing
@testable import SaneClip

@MainActor
private final class PreviewSyncCoordinator: SyncCoordinator {
    override func startSync() {
        syncStatus = .idle
    }

    override func stopSync(setStatusToDisabled: Bool = true) {
        if setStatusToDisabled {
            syncStatus = .disabled
        }
    }
}

struct SaneClipTests {
    private let screenshotOutputHintFile = URL(fileURLWithPath: "/tmp/saneclip_screenshot_dir.txt")
    private let renderBackdrop = Color(red: 0.06, green: 0.10, blue: 0.18)

    private func projectRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

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

    @Test("ClipboardManager joins multi-item plain text for capture")
    @MainActor
    func clipboardManagerJoinsMultiItemText() {
        let first = NSPasteboardItem()
        first.setString("100", forType: .string)
        let second = NSPasteboardItem()
        second.setString("200", forType: .string)
        let third = NSPasteboardItem()
        third.setString("300", forType: .string)

        let result = ClipboardManager.preferredTextForCapture(
            from: [first, second, third],
            sourceAppBundleID: nil
        )

        #expect(result == "100\n200\n300")
    }

    @Test("ClipboardManager prioritizes tabular text payloads")
    @MainActor
    func clipboardManagerPrefersTabularText() {
        let tsv = NSPasteboardItem()
        tsv.setString(
            "100\t200\n300\t400",
            forType: NSPasteboard.PasteboardType("public.tab-separated-values-text")
        )

        let result = ClipboardManager.preferredTextForCapture(
            from: [tsv],
            sourceAppBundleID: nil
        )

        #expect(result == "100\t200\n300\t400")
    }

    @Test("ClipboardManager uses plain text for known spreadsheet sources")
    @MainActor
    func clipboardManagerPrefersSpreadsheetPlainText() {
        let item = NSPasteboardItem()
        item.setString("100\n200\n300", forType: .string)

        let spreadsheetResult = ClipboardManager.preferredTextForCapture(
            from: [item],
            sourceAppBundleID: "com.microsoft.Excel"
        )
        #expect(spreadsheetResult == "100\n200\n300")

        let singleLine = NSPasteboardItem()
        singleLine.setString("just one cell", forType: .string)
        let nonSpreadsheetResult = ClipboardManager.preferredTextForCapture(
            from: [singleLine],
            sourceAppBundleID: "com.apple.Safari"
        )
        #expect(nonSpreadsheetResult == nil)
    }

    @Test("ClipboardManager prefers single-item multiline text even outside known spreadsheets")
    @MainActor
    func clipboardManagerPrefersSingleItemMultilineText() {
        let item = NSPasteboardItem()
        item.setString("100\n200\n300", forType: .string)

        let result = ClipboardManager.preferredTextForCapture(
            from: [item],
            sourceAppBundleID: "com.apple.Safari"
        )

        #expect(result == "100\n200\n300")
    }

    @Test("ClipboardManager extracts tabular text from HTML table payloads")
    @MainActor
    func clipboardManagerPrefersHTMLTableText() {
        let item = NSPasteboardItem()
        let html = """
        <table>
          <tr><th>Q1</th><th>Q2</th></tr>
          <tr><td>100</td><td>200</td></tr>
        </table>
        """
        item.setData(Data(html.utf8), forType: .html)

        let result = ClipboardManager.preferredTextForCapture(
            from: [item],
            sourceAppBundleID: "com.brave.Browser"
        )

        #expect(result == "Q1\tQ2\n100\t200")
    }

    @Test("ClipboardManager ignores non-tabular HTML payloads")
    @MainActor
    func clipboardManagerSkipsNonTabularHTML() {
        let item = NSPasteboardItem()
        let html = "<p>Hello <strong>world</strong></p>"
        item.setData(Data(html.utf8), forType: .html)

        let result = ClipboardManager.preferredTextForCapture(
            from: [item],
            sourceAppBundleID: "com.brave.Browser"
        )

        #expect(result == nil)
    }

    @Test("ClipboardManager accessibility prompt cooldown prevents loops")
    func clipboardManagerAccessibilityPromptCooldown() {
        let now = Date(timeIntervalSince1970: 1_000)
        let future = now.addingTimeInterval(15)

        #expect(ClipboardManager.shouldShowAccessibilityPrompt(now: now, suppressedUntil: nil))
        #expect(!ClipboardManager.shouldShowAccessibilityPrompt(now: now, suppressedUntil: future))
        #expect(ClipboardManager.shouldShowAccessibilityPrompt(now: future, suppressedUntil: future))
    }

    @Test("ClipboardManager accessibility prompt copy is concise")
    func clipboardManagerAccessibilityPromptCopy() {
        #expect(ClipboardManager.accessibilityAlertTitle == "Auto-Paste Needs Access")
        #expect(ClipboardManager.accessibilityAlertMessage.contains("Clip copied."))
        #expect(!ClipboardManager.accessibilityAlertMessage.contains("Privacy & Security"))
    }

    @Test("History shortcuts stay disabled while a sheet is attached")
    func historyShortcutGateBlocksForAttachedSheet() {
        #expect(!HistoryShortcutGate.shouldHandleListShortcuts(hasAttachedSheet: true, firstResponder: nil))
    }

    @Test("History shortcuts stay disabled while text input is active")
    @MainActor
    func historyShortcutGateBlocksForTextInput() {
        #expect(!HistoryShortcutGate.shouldHandleListShortcuts(hasAttachedSheet: false, firstResponder: NSTextView()))
        #expect(!HistoryShortcutGate.shouldHandleListShortcuts(hasAttachedSheet: false, firstResponder: NSTextField()))
    }

    @Test("History shortcuts stay enabled for list navigation")
    func historyShortcutGateAllowsListNavigation() {
        #expect(HistoryShortcutGate.shouldHandleListShortcuts(hasAttachedSheet: false, firstResponder: nil))
    }

    @Test("Slash only redirects focus to search when text input is inactive")
    @MainActor
    func historyShortcutSearchFocusGate() {
        #expect(HistoryShortcutGate.shouldFocusSearch(firstResponder: nil))
        #expect(!HistoryShortcutGate.shouldFocusSearch(firstResponder: NSTextView()))
        #expect(!HistoryShortcutGate.shouldFocusSearch(firstResponder: NSTextField()))
    }

    @Test("Manual update fallback only triggers for actionable Sparkle failures")
    func manualUpdateFallbackGate() {
        let installError = NSError(domain: SUSparkleErrorDomain, code: Int(SparkleErrorCode.installation.rawValue))
        let noUpdateError = NSError(domain: SUSparkleErrorDomain, code: Int(SparkleErrorCode.noUpdate.rawValue))
        let otherDomainError = NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)

        #expect(UpdateService.shouldOfferManualDownloadFallback(for: installError, updateCheck: .updates))
        #expect(!UpdateService.shouldOfferManualDownloadFallback(for: noUpdateError, updateCheck: .updates))
        #expect(!UpdateService.shouldOfferManualDownloadFallback(for: installError, updateCheck: .updatesInBackground))
        #expect(!UpdateService.shouldOfferManualDownloadFallback(for: otherDomainError, updateCheck: .updates))
    }

    @Test("Sparkle updater stays disabled for XCTest host runs")
    func sparkleUpdaterSkipsXCTestHosts() {
        #expect(UpdateService.shouldInitialize(environment: [:]))
        #expect(!UpdateService.shouldInitialize(environment: ["XCTestConfigurationFilePath": "/tmp/test.xctestconfiguration"]))
        #expect(!UpdateService.shouldInitialize(environment: ["XCTestSessionIdentifier": "session-id"]))
    }

    @Test("Sparkle test feed override only accepts non-empty values")
    func sparkleTestFeedOverride() {
        #expect(UpdateService.testFeedOverride(environment: [:]) == nil)
        #expect(UpdateService.testFeedOverride(environment: [UpdateService.testFeedOverrideKey: ""]) == nil)
        #expect(UpdateService.testFeedOverride(environment: [UpdateService.testFeedOverrideKey: "  "]) == nil)
        #expect(
            UpdateService.testFeedOverride(
                environment: [UpdateService.testFeedOverrideKey: " http://127.0.0.1:38890/appcast.xml "]
            ) == "http://127.0.0.1:38890/appcast.xml"
        )
    }

    @Test("Sparkle auto-check-on-launch test hook is opt-in")
    func sparkleAutoCheckOnLaunchFlag() {
        #expect(!UpdateService.shouldAutoCheckOnLaunch(environment: [:]))
        #expect(UpdateService.shouldAutoCheckOnLaunch(environment: [UpdateService.autoCheckOnLaunchKey: "1"]))
        #expect(!UpdateService.shouldAutoCheckOnLaunch(environment: [UpdateService.autoCheckOnLaunchKey: "0"]))
    }

    @Test("Sparkle cache maintenance targets the per-user Sparkle cache folders")
    func sparkleCacheMaintenancePaths() {
        let homeURL = URL(fileURLWithPath: "/tmp/saneclip-home", isDirectory: true)
        let urls = SparkleCacheMaintenance.staleArtifactURLs(
            bundleIdentifier: "com.saneclip.app",
            homeDirectoryURL: homeURL
        )

        #expect(urls.map(\.path) == [
            "/tmp/saneclip-home/Library/Caches/com.saneclip.app/org.sparkle-project.Sparkle/Launcher",
            "/tmp/saneclip-home/Library/Caches/com.saneclip.app/org.sparkle-project.Sparkle/Installation",
            "/tmp/saneclip-home/Library/Caches/com.saneclip.app/org.sparkle-project.Sparkle/PersistentDownloads",
        ])
    }

    @Test("Manual update check clears stale Sparkle cache artifacts")
    func sparkleCacheMaintenanceClearsArtifacts() throws {
        let fileManager = FileManager.default
        let homeURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: homeURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: homeURL) }

        let staleFolders = SparkleCacheMaintenance.staleArtifactURLs(
            bundleIdentifier: "com.saneclip.app",
            homeDirectoryURL: homeURL
        )
        for folder in staleFolders {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data("stale".utf8).write(to: folder.appendingPathComponent("artifact.txt"))
        }

        let removed = UpdateService.clearStaleSparkleArtifacts(
            bundleIdentifier: "com.saneclip.app",
            fileManager: fileManager,
            homeDirectoryURL: homeURL
        )

        #expect(Set(removed) == Set(["Launcher", "Installation", "PersistentDownloads"]))
        #expect(staleFolders.allSatisfy { !fileManager.fileExists(atPath: $0.path) })
    }

    @Test("Sandboxed direct build enables Sparkle installer launcher service")
    func sparkleInstallerLauncherServiceEnabledInInfoPlist() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let plistURL = repoRoot.appendingPathComponent("SaneClip/Info.plist")
        let plistData = try Data(contentsOf: plistURL)
        let plist = try #require(
            PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        )

        #expect(plist["SUEnableInstallerLauncherService"] as? Bool == true)
    }

    @Test("Sandboxed direct build grants Sparkle installer mach lookup exceptions")
    func sparkleInstallerMachLookupExceptionsPresent() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let entitlementsURL = repoRoot.appendingPathComponent("SaneClip/SaneClip.entitlements")
        let entitlementsData = try Data(contentsOf: entitlementsURL)
        let entitlements = try #require(
            PropertyListSerialization.propertyList(from: entitlementsData, format: nil) as? [String: Any]
        )
        let machLookupNames = Set(
            (entitlements["com.apple.security.temporary-exception.mach-lookup.global-name"] as? [String]) ?? []
        )

        #expect(machLookupNames.contains("$(PRODUCT_BUNDLE_IDENTIFIER)-spki"))
        #expect(machLookupNames.contains("$(PRODUCT_BUNDLE_IDENTIFIER)-spks"))
    }

    @Test("Appcast forces pre-2208 builds onto the manual download path")
    func sparkleAppcastProtectsPreInstallerLauncherBuilds() throws {
        let repoRoot = projectRootURL()
        let appcastURL = repoRoot.appendingPathComponent("docs/appcast.xml")
        let appcast = try String(contentsOf: appcastURL, encoding: .utf8)
        let latestItemRange = try #require(
            appcast.range(of: #"<item>\s*<title>2\.2\.12</title>[\s\S]*?</item>"#, options: .regularExpression)
        )
        let latestItem = String(appcast[latestItemRange])

        #expect(latestItem.contains("<title>2.2.12</title>"))
        #expect(latestItem.contains("<link>https://saneclip.com/download</link>"))
        #expect(latestItem.contains("<sparkle:informationalUpdate>"))
        #expect(latestItem.contains("<sparkle:belowVersion>2208</sparkle:belowVersion>"))
    }

    @Test("Website download CTAs route through the manual install guide")
    func websiteDownloadCtasUseManualGuide() throws {
        let repoRoot = projectRootURL()
        let indexURL = repoRoot.appendingPathComponent("docs/index.html")
        let indexSource = try String(contentsOf: indexURL, encoding: .utf8)

        #expect(indexSource.contains("href=\"/download\" class=\"mobile-nav-cta\""))
        #expect(indexSource.contains("href=\"/download\" class=\"pricing-cta pricing-cta-free\""))
        #expect(indexSource.contains("href=\"/download\" class=\"sustainability-option\""))
        #expect(!indexSource.contains("https://dist.saneclip.com/updates/SaneClip-2.2.12.zip\" class=\"pricing-cta pricing-cta-free\""))
    }

    @Test("Download guide warns against duplicate app installs")
    func manualDownloadGuideWarnsAboutDuplicateApps() throws {
        let repoRoot = projectRootURL()
        let downloadURL = repoRoot.appendingPathComponent("docs/download.html")
        let downloadSource = try String(contentsOf: downloadURL, encoding: .utf8)

        #expect(downloadSource.contains("Do <strong>not</strong> unzip SaneClip directly inside <code>/Applications</code>."))
        #expect(downloadSource.contains("choose <strong>Replace</strong>"))
        #expect(downloadSource.contains("delete the extra one and keep only <code>/Applications/SaneClip.app</code>"))
        #expect(downloadSource.contains("fetch('/appcast.xml'"))
    }

    @Test("iPhone settings restore the App Store screenshot accent lane")
    func iPhoneSettingsSourceMatchesScreenshotLane() throws {
        let repoRoot = projectRootURL()
        let settingsURL = repoRoot.appendingPathComponent("iOS/Views/SettingsTab.swift")
        let settingsSource = try String(contentsOf: settingsURL, encoding: .utf8)

        #expect(settingsSource.contains("labelColor: Color = .clipBlue"))
        #expect(settingsSource.contains("Link(destination: URL(string: \"https://saneclip.com\")!)"))
        #expect(!settingsSource.contains("View Issues"))
        #expect(!settingsSource.contains("Report a Bug"))
    }

    @Test("iPhone screenshot mode keeps history chrome aligned with App Store assets")
    func screenshotModeHistoryChromeMatchesAssetLane() throws {
        let repoRoot = projectRootURL()
        let historyURL = repoRoot.appendingPathComponent("iOS/Views/HistoryTab.swift")
        let historySource = try String(contentsOf: historyURL, encoding: .utf8)

        #expect(historySource.contains(".navigationTitle(\"History\")"))
        #expect(historySource.contains("if !isScreenshotMode"))
        #expect(historySource.contains("viewModel.isShowingDemoData && !isScreenshotMode"))
    }

    @Test("Sandboxed builds allow user-selected file access for open and save panels")
    func sandboxedBuildsGrantUserSelectedFileAccess() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        for relativePath in ["SaneClip/SaneClip.entitlements", "SaneClip/SaneClipAppStore.entitlements"] {
            let entitlementsURL = repoRoot.appendingPathComponent(relativePath)
            let entitlementsData = try Data(contentsOf: entitlementsURL)
            let entitlements = try #require(
                PropertyListSerialization.propertyList(from: entitlementsData, format: nil) as? [String: Any]
            )

            #expect(entitlements["com.apple.security.files.user-selected.read-write"] as? Bool == true)
        }
    }

    @Test("ClipboardManager free tier history limit is capped at 50")
    func clipboardManagerFreeTierHistoryLimit() {
        #expect(ClipboardManager.historyLimit(maxHistorySize: 500, isPro: false) == 50)
        #expect(ClipboardManager.historyLimit(maxHistorySize: 50, isPro: false) == 50)
        #expect(ClipboardManager.historyLimit(maxHistorySize: 12, isPro: false) == 12)
    }

    @Test("ClipboardManager pro tier history limit respects configured max")
    func clipboardManagerProTierHistoryLimit() {
        #expect(ClipboardManager.historyLimit(maxHistorySize: 500, isPro: true) == 500)
        #expect(ClipboardManager.historyLimit(maxHistorySize: 50, isPro: true) == 50)
    }

    @Test("Snippet intents require Pro")
    @MainActor
    func snippetIntentsRequirePro() async {
        let listIntent = ListSnippetsIntent()
        do {
            _ = try await listIntent.perform()
            #expect(Bool(false))
        } catch IntentError.proFeatureRequiresPro {
            #expect(true)
        } catch {
            #expect(Bool(false))
        }

        let pasteIntent = PasteSnippetIntent()
        pasteIntent.snippetName = "any"
        do {
            _ = try await pasteIntent.perform()
            #expect(Bool(false))
        } catch IntentError.proFeatureRequiresPro {
            #expect(true)
        } catch {
            #expect(Bool(false))
        }
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

    @Test("SettingsModel round-trips open-history-at-cursor preference")
    @MainActor
    func settingsModelOpenHistoryAtCursorRoundTrip() throws {
        let settings = SettingsModel.shared
        let original = settings.openHistoryAtCursor
        defer { settings.openHistoryAtCursor = original }

        let payload: [String: Any] = [
            "version": 1,
            "openHistoryAtCursor": true
        ]
        let exported = try JSONSerialization.data(withJSONObject: payload)

        settings.openHistoryAtCursor = false
        try settings.importSettings(from: exported)

        #expect(settings.openHistoryAtCursor == true)
    }

    @Test("SettingsModel keeps Dock hidden by default")
    func settingsModelDockDefaultIsHidden() {
        #expect(SettingsModel.defaultShowInDock == false)
    }

    @Test("SettingsModel normalizes unsupported capture size values")
    func settingsModelNormalizesCaptureSizes() {
        #expect(SettingsModel.normalizedCaptureTextBytes(64 * 1024) == 64 * 1024)
        #expect(SettingsModel.normalizedCaptureTextBytes(123_456) == 256 * 1024)

        #expect(SettingsModel.normalizedCaptureImageBytes(10 * 1024 * 1024) == 10 * 1024 * 1024)
        #expect(SettingsModel.normalizedCaptureImageBytes(7_654_321) == 5 * 1024 * 1024)
    }

    @Test("URL tracking parameters are stripped")
    func urlTrackingParamsStripped() {
        let urlWithTracking = "https://example.com/page?" +
            "utm_source=newsletter&utm_medium=email&real_param=keep&fbclid=abc123"
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

    // MARK: - Extended Text Transforms (Phase 2)

    @Test("Reverse lines reverses multi-line text")
    func testReverseLines() {
        let input = "Line 1\nLine 2\nLine 3"
        let result = TextTransform.reverseLines.apply(to: input)

        #expect(result == "Line 3\nLine 2\nLine 1")
    }

    @Test("JSON pretty print formats valid JSON")
    func testJsonPrettyPrint() {
        let input = #"{"name":"John","age":30}"#
        let result = TextTransform.jsonPrettyPrint.apply(to: input)

        #expect(result.contains("  "))  // Has indentation
        #expect(result.contains("\n"))  // Has newlines
        #expect(result.contains("\"name\""))
    }

    @Test("JSON pretty print returns original for invalid JSON")
    func testJsonPrettyPrintInvalid() {
        let input = "not valid json { broken"
        let result = TextTransform.jsonPrettyPrint.apply(to: input)

        #expect(result == input)  // Returns original unchanged
    }

    @Test("Strip HTML removes tags and keeps text")
    func testStripHTML() {
        let input = "<p>Hello <strong>world</strong>!</p>"
        let result = TextTransform.stripHTML.apply(to: input)

        #expect(!result.contains("<"))
        #expect(!result.contains(">"))
        #expect(result.contains("Hello"))
        #expect(result.contains("world"))
    }

    @Test("Strip Markdown removes formatting")
    func testMarkdownToPlain() {
        let input = "# Header\n**bold** and *italic* text"
        let result = TextTransform.markdownToPlain.apply(to: input)

        #expect(!result.contains("#"))
        #expect(!result.contains("**"))
        #expect(!result.contains("*"))
        #expect(result.contains("bold"))
        #expect(result.contains("italic"))
    }

    @Test("Strip Markdown handles links")
    func testMarkdownLinksStripped() {
        let input = "Check out [this link](https://example.com) for more info"
        let result = TextTransform.markdownToPlain.apply(to: input)

        #expect(!result.contains("["))
        #expect(!result.contains("]("))
        #expect(result.contains("this link"))
    }

    // MARK: - Clipboard Rules Engine Tests (Phase 2)

    @Test("ClipboardRulesManager normalizes line endings")
    @MainActor
    func testNormalizeLineEndings() {
        let rules = ClipboardRulesManager.shared

        // Save original state
        let originalValue = rules.normalizeLineEndings

        // Enable rule
        rules.normalizeLineEndings = true

        // Disable other rules to isolate test
        let originalTrim = rules.autoTrimWhitespace
        let originalSpaces = rules.removeDuplicateSpaces
        let originalLowercase = rules.lowercaseURLs
        let originalTracking = rules.stripTrackingParams

        rules.autoTrimWhitespace = false
        rules.removeDuplicateSpaces = false
        rules.lowercaseURLs = false
        rules.stripTrackingParams = false

        let input = "Line 1\r\nLine 2\rLine 3\nLine 4"
        let result = rules.process(input)

        #expect(!result.contains("\r"))
        #expect(result == "Line 1\nLine 2\nLine 3\nLine 4")

        // Restore original state
        rules.normalizeLineEndings = originalValue
        rules.autoTrimWhitespace = originalTrim
        rules.removeDuplicateSpaces = originalSpaces
        rules.lowercaseURLs = originalLowercase
        rules.stripTrackingParams = originalTracking
    }

    @Test("ClipboardRulesManager removes duplicate spaces")
    @MainActor
    func testRemoveDuplicateSpaces() {
        let rules = ClipboardRulesManager.shared

        // Save original state
        let originalSpaces = rules.removeDuplicateSpaces
        let originalTrim = rules.autoTrimWhitespace
        let originalTracking = rules.stripTrackingParams
        let originalLineEndings = rules.normalizeLineEndings
        let originalLowercase = rules.lowercaseURLs

        // Configure for isolated test
        rules.removeDuplicateSpaces = true
        rules.autoTrimWhitespace = false
        rules.stripTrackingParams = false
        rules.normalizeLineEndings = false
        rules.lowercaseURLs = false

        let input = "Hello    world  test"
        let result = rules.process(input)

        #expect(result == "Hello world test")

        // Restore
        rules.removeDuplicateSpaces = originalSpaces
        rules.autoTrimWhitespace = originalTrim
        rules.stripTrackingParams = originalTracking
        rules.normalizeLineEndings = originalLineEndings
        rules.lowercaseURLs = originalLowercase
    }

    // MARK: - Sensitive Data Detection Tests (Phase 3)

    @Test("Detects valid credit card numbers with Luhn validation")
    func testCreditCardDetection() {
        let detector = SensitiveDataDetector.shared

        // Valid Visa test number
        let validCard = "4111 1111 1111 1111"
        let detected = detector.detect(in: validCard)
        #expect(detected.contains(.creditCard))

        // Invalid number (fails Luhn)
        let invalidCard = "4111 1111 1111 1112"
        let notDetected = detector.detect(in: invalidCard)
        #expect(!notDetected.contains(.creditCard))
    }

    @Test("Detects SSN patterns")
    func testSSNDetection() {
        let detector = SensitiveDataDetector.shared

        // Standard format with dashes
        let ssn = "My SSN is 123-45-6789"
        let detected = detector.detect(in: ssn)
        #expect(detected.contains(.ssn))

        // Plain numbers need context
        let plainSSN = "SSN: 123456789"
        let plainDetected = detector.detect(in: plainSSN)
        #expect(plainDetected.contains(.ssn))
    }

    @Test("Detects common API key patterns")
    func testAPIKeyDetection() {
        let detector = SensitiveDataDetector.shared

        // OpenAI key pattern
        let openAI = "sk-abc123def456ghi789jkl012mno345pqr678"
        #expect(detector.detect(in: openAI).contains(.apiKey))

        // GitHub PAT pattern
        let github = "ghp_abcdefghijklmnopqrstuvwxyz1234567890"
        #expect(detector.detect(in: github).contains(.apiKey))

        // AWS Access Key ID
        let aws = "AKIAIOSFODNN7EXAMPLE"
        #expect(detector.detect(in: aws).contains(.apiKey))
    }

    @Test("Detects password patterns")
    func testPasswordDetection() {
        let detector = SensitiveDataDetector.shared

        let passwordAssignment = "password: mySecretPass123"
        #expect(detector.detect(in: passwordAssignment).contains(.password))

        let pwdEquals = "pwd=supersecret"
        #expect(detector.detect(in: pwdEquals).contains(.password))
    }

    @Test("Detects private key blocks")
    func testPrivateKeyDetection() {
        let detector = SensitiveDataDetector.shared

        let rsaKey = """
        -----BEGIN RSA PRIVATE KEY-----
        MIIEowIBAAKCAQEA...
        -----END RSA PRIVATE KEY-----
        """
        #expect(detector.detect(in: rsaKey).contains(.privateKey))

        let sshKey = "-----BEGIN OPENSSH PRIVATE KEY-----"
        #expect(detector.detect(in: sshKey).contains(.privateKey))
    }

    @Test("Detects email addresses")
    func testEmailDetection() {
        let detector = SensitiveDataDetector.shared

        let email = "Contact me at john.doe@example.com for more info"
        #expect(detector.detect(in: email).contains(.email))
    }

    @Test("No false positives on normal text")
    func testNoFalsePositives() {
        let detector = SensitiveDataDetector.shared

        let normalText = "Hello, this is a normal message with no sensitive data."
        #expect(detector.detect(in: normalText).isEmpty)

        let shortNumbers = "My phone is 555-1234"
        #expect(!detector.detect(in: shortNumbers).contains(.creditCard))
    }

    @Test("SyncCoordinator maps not-authenticated errors to no-account status")
    func syncCoordinatorNotAuthenticatedStatus() {
        #expect(SyncCoordinator.status(for: .notAuthenticated) == .noAccount)
    }

    @Test("SyncCoordinator maps other CloudKit errors to generic error status")
    func syncCoordinatorGenericErrorStatus() {
        #expect(SyncCoordinator.status(for: .networkUnavailable) == .error)
    }

    @Test("SyncCoordinator failure diagnostics include CloudKit domain and code")
    func syncCoordinatorFailureDiagnostic() {
        let error = CKError(.networkUnavailable)
        let diagnostic = SyncCoordinator.failureDiagnostic(message: "Manual sync failed", error: error)

        #expect(diagnostic.contains("Manual sync failed"))
        #expect(diagnostic.contains("CKErrorDomain"))
        #expect(diagnostic.contains("code=3"))
        #expect(diagnostic.contains("status=Error"))
    }

    @Test("SharedClipboardItem text round-trips through stored iOS persistence")
    func sharedClipboardItemStoredTextRoundTrip() throws {
        let item = SharedClipboardItem(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            content: .text("This is a long piece of text that should stay intact across relaunches."),
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            sourceAppBundleID: "com.apple.MobileSMS",
            sourceAppName: "Messages",
            pasteCount: 2,
            note: "keep this",
            deviceId: "ios-device",
            deviceName: "iPhone"
        )

        let stored = item.storedItem
        let restored = try #require(SharedClipboardItem(storedItem: stored))

        #expect(restored.fullText == item.fullText)
        #expect(restored.note == "keep this")
        #expect(restored.sourceAppName == "Messages")
    }

    @Test("SharedClipboardItem image round-trips through stored iOS persistence")
    func sharedClipboardItemStoredImageRoundTrip() throws {
        let data = Data([0x00, 0x01, 0x02, 0x03])
        let item = SharedClipboardItem(
            content: .imageData(data, width: 32, height: 18),
            deviceId: "ios-device",
            deviceName: "iPhone"
        )

        let stored = item.storedItem
        let restored = try #require(SharedClipboardItem(storedItem: stored))

        guard case let .imageData(restoredData, width, height) = restored.content else {
            Issue.record("Expected restored image content")
            return
        }

        #expect(restoredData == data)
        #expect(width == 32)
        #expect(height == 18)
    }

    @Test("SyncCoordinator seeds existing history records when sync starts fresh")
    func syncCoordinatorInitialRecordSeeding() {
        let first = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let second = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

        let recordNames = SyncCoordinator.initialRecordNamesToSeed(
            historyIDs: [first, second],
            pendingRecordNames: Set<String>()
        )

        #expect(recordNames == [first.uuidString, second.uuidString])
    }

    @Test("SyncCoordinator defers initial local seed until the zone bootstrap completes")
    func syncCoordinatorDefersInitialSeedUntilZoneBootstrap() {
        #expect(
            SyncCoordinator.shouldQueueInitialLocalSeedAfterZoneBootstrap(
                previousStateExists: false,
                savedZoneCount: 1
            )
        )
        #expect(
            !SyncCoordinator.shouldQueueInitialLocalSeedAfterZoneBootstrap(
                previousStateExists: true,
                savedZoneCount: 1
            )
        )
        #expect(
            !SyncCoordinator.shouldQueueInitialLocalSeedAfterZoneBootstrap(
                previousStateExists: false,
                savedZoneCount: 0
            )
        )
    }

    @Test("SyncCoordinator resets stale iPhone sync state when upgrading from pre-2.2.6")
    func syncCoordinatorResetsStaleIOSBootstrapStateOnUpgrade() {
        #expect(
            SyncCoordinator.shouldResetStaleIOSBootstrapState(
                previousStateExists: true,
                lastRunAppVersion: "2.1",
                currentAppVersion: "2.2.6"
            )
        )
        #expect(
            SyncCoordinator.shouldResetStaleIOSBootstrapState(
                previousStateExists: true,
                lastRunAppVersion: nil,
                currentAppVersion: "2.2.8"
            )
        )
        #expect(
            !SyncCoordinator.shouldResetStaleIOSBootstrapState(
                previousStateExists: false,
                lastRunAppVersion: "2.1",
                currentAppVersion: "2.2.6"
            )
        )
        #expect(
            !SyncCoordinator.shouldResetStaleIOSBootstrapState(
                previousStateExists: true,
                lastRunAppVersion: "2.2.6",
                currentAppVersion: "2.2.6"
            )
        )
        #expect(
            !SyncCoordinator.shouldResetStaleIOSBootstrapState(
                previousStateExists: true,
                lastRunAppVersion: "2.2.8",
                currentAppVersion: "2.2.8"
            )
        )
        #expect(
            !SyncCoordinator.shouldResetStaleIOSBootstrapState(
                previousStateExists: true,
                lastRunAppVersion: "2.1",
                currentAppVersion: "2.2.5"
            )
        )
    }

    @Test("SyncCoordinator offers manual reset when sync state or diagnostics exist")
    func syncCoordinatorOffersManualReset() {
        #expect(
            SyncCoordinator.shouldOfferManualReset(
                isSyncEnabled: true,
                lastSyncDate: nil,
                connectedDeviceCount: 0,
                hasPersistedState: false
            )
        )
        #expect(
            SyncCoordinator.shouldOfferManualReset(
                isSyncEnabled: false,
                lastSyncDate: Date(timeIntervalSince1970: 1),
                connectedDeviceCount: 0,
                hasPersistedState: false
            )
        )
        #expect(
            SyncCoordinator.shouldOfferManualReset(
                isSyncEnabled: false,
                lastSyncDate: nil,
                connectedDeviceCount: 2,
                hasPersistedState: false
            )
        )
        #expect(
            SyncCoordinator.shouldOfferManualReset(
                isSyncEnabled: false,
                lastSyncDate: nil,
                connectedDeviceCount: 0,
                hasPersistedState: true
            )
        )
        #expect(
            !SyncCoordinator.shouldOfferManualReset(
                isSyncEnabled: false,
                lastSyncDate: nil,
                connectedDeviceCount: 0,
                hasPersistedState: false
            )
        )
    }

    @Test("SyncCoordinator restart decision preserves current sync toggle")
    func syncCoordinatorRestartDecisionAfterManualReset() {
        #expect(SyncCoordinator.shouldRestartSyncAfterManualReset(isSyncEnabled: true))
        #expect(!SyncCoordinator.shouldRestartSyncAfterManualReset(isSyncEnabled: false))
    }

    @Test("SyncCoordinator relies on CKSyncEngine automatic send after bootstrap seeding")
    func syncCoordinatorUsesAutomaticSendAfterBootstrapSeed() {
        #expect(
            SyncCoordinator.postBootstrapSeedFollowUp(seededRecordCount: 2) == .waitForAutomaticSend
        )
        #expect(
            SyncCoordinator.postBootstrapSeedFollowUp(seededRecordCount: 0) == .none
        )
    }

    @Test("SyncCoordinator does not re-seed already pending history records")
    func syncCoordinatorSkipsPendingRecordSeeds() {
        let first = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let second = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

        let recordNames = SyncCoordinator.initialRecordNamesToSeed(
            historyIDs: [first, second],
            pendingRecordNames: [first.uuidString]
        )

        #expect(recordNames == [second.uuidString])
    }

    @Test("SyncCoordinator keeps full local items when filtering seed candidates")
    func syncCoordinatorFiltersInitialLocalSeedItems() {
        let first = SharedClipboardItem(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            content: .text("first")
        )
        let second = SharedClipboardItem(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            content: .text("second")
        )

        let items = SyncCoordinator.initialLocalSeedItems(
            items: [first, second],
            pendingRecordNames: [first.id.uuidString]
        )

        #expect(items.map(\.id) == [second.id])
        #expect(items.first?.fullText == "second")
    }

    @Test("SyncCoordinator blocks remote deletions while initial local seed is pending")
    func syncCoordinatorBlocksRemoteDeletesDuringInitialSeed() {
        #expect(
            SyncCoordinator.shouldApplyRemoteDeletions(
                isInitialLocalSeedPending: true,
                pendingRecordCount: 2
            ) == false
        )
    }

    @Test("SyncCoordinator allows remote deletions once initial seed is clear")
    func syncCoordinatorAllowsRemoteDeletesAfterInitialSeed() {
        #expect(
            SyncCoordinator.shouldApplyRemoteDeletions(
                isInitialLocalSeedPending: true,
                pendingRecordCount: 0
            ) == true
        )
    }

    @Test("SyncCoordinator resets state when the primary sync zone is deleted")
    func syncCoordinatorResetsForPrimaryZoneDeletion() {
        #expect(
            SyncCoordinator.shouldResetSyncState(
                forDeletedZoneIDs: [SyncDataModel.zoneID]
            )
        )
    }

    @Test("SyncCoordinator ignores unrelated zone deletions")
    func syncCoordinatorIgnoresUnrelatedZoneDeletion() {
        let otherZoneID = CKRecordZone.ID(zoneName: "other-zone", ownerName: CKCurrentUserDefaultName)
        #expect(
            !SyncCoordinator.shouldResetSyncState(
                forDeletedZoneIDs: [otherZoneID]
            )
        )
    }

    @Test("SyncCoordinator only tracks pending save record IDs")
    func syncCoordinatorPendingSaveRecordIDs() {
        let saveID = CKRecord.ID(
            recordName: "11111111-1111-1111-1111-111111111111",
            zoneID: SyncDataModel.zoneID
        )
        let deleteID = CKRecord.ID(
            recordName: "22222222-2222-2222-2222-222222222222",
            zoneID: SyncDataModel.zoneID
        )

        let pendingIDs = SyncCoordinator.pendingSaveRecordIDs(
            from: [
                .saveRecord(saveID),
                .deleteRecord(deleteID),
            ]
        )

        #expect(pendingIDs == [saveID])
    }

    @Test("SaneClip launch eagerly initializes sync once clipboard history is ready")
    func saneClipLaunchSyncBootstrapGate() {
        #expect(!SaneClipAppDelegate.shouldInitializeSyncOnLaunch(
            hasClipboardManager: false,
            syncFeatureCompiled: true
        ))
        #expect(!SaneClipAppDelegate.shouldInitializeSyncOnLaunch(
            hasClipboardManager: true,
            syncFeatureCompiled: false
        ))
        #expect(SaneClipAppDelegate.shouldInitializeSyncOnLaunch(
            hasClipboardManager: true,
            syncFeatureCompiled: true
        ))
    }

    @Test("ExcludedAppsInline reads bundle identifiers from selected app bundles")
    func excludedAppsInlineReadsBundleIDFromAppURL() throws {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appURL = tempRoot.appendingPathComponent("Fake.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let plistURL = contentsURL.appendingPathComponent("Info.plist")

        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "CFBundleIdentifier": "com.example.fake",
            "CFBundleName": "Fake"
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try plistData.write(to: plistURL)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        #expect(ExcludedAppsInline.selectedBundleID(fromSelectedAppURL: appURL) == "com.example.fake")
    }

    @Test("ExcludedAppsInline rejects non-app selections")
    func excludedAppsInlineRejectsNonAppSelections() throws {
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        #expect(ExcludedAppsInline.selectedBundleID(fromSelectedAppURL: tempRoot) == nil)
    }

    @Test("ExcludedAppsInline avoids duplicate bundle IDs when adding exclusions")
    func excludedAppsInlineDeduplicatesBundleIDs() {
        let updated = ExcludedAppsInline.updatedExcludedApps(
            afterAdding: "com.example.fake",
            to: ["com.example.fake"]
        )

        #expect(updated == ["com.example.fake"])
    }

    @Test("ExcludedAppsInline keyboard selection moves predictably through excluded app rows")
    func excludedAppsInlineKeyboardSelectionMovement() {
        let apps = ["com.example.one", "com.example.two", "com.example.three"]

        #expect(ExcludedAppsInline.nextExcludedAppSelection(current: nil, excludedApps: apps, direction: 1) == "com.example.one")
        #expect(ExcludedAppsInline.nextExcludedAppSelection(current: "com.example.one", excludedApps: apps, direction: 1) == "com.example.two")
        #expect(ExcludedAppsInline.nextExcludedAppSelection(current: "com.example.three", excludedApps: apps, direction: 1) == "com.example.three")
        #expect(ExcludedAppsInline.nextExcludedAppSelection(current: "com.example.two", excludedApps: apps, direction: -1) == "com.example.one")
        #expect(ExcludedAppsInline.nextExcludedAppSelection(current: "com.example.one", excludedApps: apps, direction: -1) == "com.example.one")
    }

    @Test("SettingsView command-digit mapping follows sidebar order")
    func settingsViewCommandDigitMapping() {
        for (index, tab) in SettingsView.SettingsTab.allCases.enumerated() {
            #expect(SettingsView.tab(forShortcutIndex: index) == tab)
        }

        #expect(SettingsView.tab(forShortcutIndex: -1) == nil)
        #expect(SettingsView.tab(forShortcutIndex: SettingsView.SettingsTab.allCases.count) == nil)
    }

    @Test("SettingsView uses shared SaneUI settings chrome")
    func settingsViewUsesSharedSaneUIChrome() throws {
        let settingsSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("UI/Settings/SettingsView.swift"),
            encoding: .utf8
        )
        let directSupportSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("DirectDistributionSupport.swift"),
            encoding: .utf8
        )
        let iosSettingsSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("iOS/Views/SettingsTab.swift"),
            encoding: .utf8
        )

        #expect(settingsSource.contains("SaneSettingsContainer(defaultTab: .general, selection: $selectedTab, windowSizing: .embedded)"))
        #expect(settingsSource.contains("SaneSettingsIconSemantic.general.color"))
        #expect(settingsSource.contains("SaneSettingsIconSemantic.shortcuts.color"))
        #expect(settingsSource.contains("SaneSettingsIconSemantic.content.color"))
        #expect(settingsSource.contains("SaneSettingsIconSemantic.storage.color"))
        #expect(settingsSource.contains("SaneSettingsIconSemantic.license.color"))
        #expect(settingsSource.contains("SaneSettingsIconSemantic.about.color"))
        #expect(!settingsSource.contains("struct SettingsGradientBackground"))
        #expect(!settingsSource.contains("struct VisualEffectBlur"))
        #expect(!settingsSource.contains("struct CompactSection<"))
        #expect(!settingsSource.contains("struct CompactRow<"))
        #expect(!settingsSource.contains("struct CompactToggle"))
        #expect(!settingsSource.contains("struct CompactDivider"))
        #expect(!settingsSource.contains("struct GlassGroupBoxStyle"))
        #expect(settingsSource.contains("SaneLanguageSettingsRow()"))
        #expect(settingsSource.contains("SaneClipSettingsCopy.menuBarIconListTitle"))
        #expect(settingsSource.contains("SaneClipSettingsCopy.removeButtonTitle"))
        #expect(settingsSource.contains("typealias ClipActionButtonStyle = SaneUI.SaneActionButtonStyle"))
        #expect(settingsSource.contains(".buttonStyle(ClipActionButtonStyle())"))
        #expect(settingsSource.contains("ClipActionButtonStyle(prominent: exists, compact: true)"))
        #expect(settingsSource.contains("Image(nsImage: popupSymbolImage(settings.menuBarIcon))"))
        #expect(settingsSource.contains("hierarchicalColor: .white"))
        #expect(settingsSource.contains("symbol.isTemplate = false"))
        #expect(settingsSource.contains("LicenseSettingsView(licenseService: licenseService, style: .panel)"))
        #expect(settingsSource.contains("SaneAboutView("))
        #expect(!settingsSource.contains("mailto:hi@saneapps.com"))
        #expect(!directSupportSource.contains("struct SaneSparkleRow"))
        #expect(!iosSettingsSource.contains("mailto:hi@saneapps.com"))
        #expect(iosSettingsSource.contains("https://github.com/sane-apps/SaneClip/issues"))
    }

    @Test("Settings screens keep readable typography and contrast tokens")
    func settingsScreensUseReadableTypography() throws {
        let settingsFiles = [
            "UI/Settings/SettingsView.swift",
            "UI/Settings/SnippetsSettingsView.swift",
            "UI/Settings/StorageStatsView.swift",
            "Core/Sync/SyncSettingsView.swift"
        ]
        let disallowedSubstrings = [
            ".font(.caption)",
            ".font(.caption2)",
            ".foregroundStyle(.secondary)",
            ".foregroundStyle(.tertiary)",
            ".font(.system(size: 9)",
            ".font(.system(size: 10)",
            ".font(.system(size: 11)"
        ]

        for relativePath in settingsFiles {
            let source = try String(
                contentsOf: projectRootURL().appendingPathComponent(relativePath),
                encoding: .utf8
            )

            for forbidden in disallowedSubstrings {
                #expect(
                    !source.contains(forbidden),
                    Comment("\(relativePath) still contains disallowed settings styling: \(forbidden)")
                )
            }
        }
    }

    @Test("Menu bar symbol images are template-rendered for system contrast")
    func menuBarTemplateImageUsesTemplateRendering() throws {
        let appSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("SaneClipApp.swift"),
            encoding: .utf8
        )

        #expect(appSource.contains("image?.isTemplate = true"))
        #expect(appSource.contains("button.image = menuBarTemplateImage(named: iconName)"))
    }

    @Test("No-keychain fallback stays in SaneClip standard defaults")
    func noKeychainFallbackUsesStandardDefaults() throws {
        let keychainSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("Core/Security/KeychainHelper.swift"),
            encoding: .utf8
        )

        #expect(keychainSource.contains(".standard"))
        #expect(!keychainSource.contains("UserDefaults(suiteName: \"com.saneclip.no-keychain\")"))
    }

    @Test("Render settings screenshots when requested")
    @MainActor
    func renderSettingsScreenshots() throws {
        guard let rawOutputDir = screenshotOutputDirectory()
        else {
            return
        }

        let outputDir = URL(
            fileURLWithPath: NSString(string: rawOutputDir).expandingTildeInPath,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        try renderPNG(
            ZStack {
                renderBackdrop.opacity(0.3)
                    .ignoresSafeArea()
                GeneralSettingsView(licenseService: nil)
            }
                .preferredColorScheme(.dark)
                .frame(width: 1000, height: 760),
            size: CGSize(width: 1000, height: 760),
            to: outputDir.appendingPathComponent("settings-general-render.png")
        )

        try renderPNG(
            ZStack {
                renderBackdrop.opacity(0.3)
                    .ignoresSafeArea()
                ShortcutsSettingsView(licenseService: nil)
            }
                .preferredColorScheme(.dark)
                .frame(width: 1000, height: 760),
            size: CGSize(width: 1000, height: 760),
            to: outputDir.appendingPathComponent("settings-shortcuts-render.png")
        )

        try renderPNG(
            ZStack {
                renderBackdrop.opacity(0.3)
                    .ignoresSafeArea()
                SnippetsSettingsView(licenseService: nil)
            }
                .preferredColorScheme(.dark)
                .frame(width: 1000, height: 760),
            size: CGSize(width: 1000, height: 760),
            to: outputDir.appendingPathComponent("settings-snippets-render.png")
        )

        try renderPNG(
            ZStack {
                renderBackdrop.opacity(0.3)
                    .ignoresSafeArea()
                SyncSettingsView()
            }
                .preferredColorScheme(.dark)
                .frame(width: 1000, height: 760),
            size: CGSize(width: 1000, height: 760),
            to: outputDir.appendingPathComponent("settings-sync-render.png")
        )

        let previewSyncCoordinator = PreviewSyncCoordinator()
        previewSyncCoordinator.isSyncEnabled = true
        previewSyncCoordinator.syncStatus = .idle
        previewSyncCoordinator.lastSyncDate = Date().addingTimeInterval(-120)
        previewSyncCoordinator.connectedDevices = ["MacBook Pro", "iPhone"]

        try renderPNG(
            ZStack {
                renderBackdrop.opacity(0.3)
                    .ignoresSafeArea()
                SyncSettingsView(coordinator: previewSyncCoordinator)
            }
                .preferredColorScheme(.dark)
                .frame(width: 1000, height: 860),
            size: CGSize(width: 1000, height: 860),
            to: outputDir.appendingPathComponent("settings-sync-enabled-render.png")
        )

        try renderPNG(
            ZStack {
                renderBackdrop.opacity(0.3)
                    .ignoresSafeArea()
                StorageStatsView()
                    .padding(20)
            }
                .preferredColorScheme(.dark)
                .frame(width: 1000, height: 760),
            size: CGSize(width: 1000, height: 760),
            to: outputDir.appendingPathComponent("settings-storage-render.png")
        )

        let previewLicenseService = LicenseService(
            appName: "SaneClip",
            purchaseBackend: .appStore(productID: "com.saneclip.app.pro.unlock")
        )
        let previewAboutLicenses = [
            SaneAboutView.LicenseEntry(
                name: "KeyboardShortcuts",
                url: "https://github.com/sindresorhus/KeyboardShortcuts",
                text: "MIT License"
            )
        ]
        try renderPNG(
            ZStack {
                renderBackdrop.opacity(0.3)
                    .ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    LicenseSettingsView(licenseService: previewLicenseService, style: .panel)
                        .frame(maxWidth: 420, alignment: .leading)
                    Spacer(minLength: 0)
                }
                .padding(20)
            }
                .preferredColorScheme(.dark)
                .frame(width: 1000, height: 760),
            size: CGSize(width: 1000, height: 760),
            to: outputDir.appendingPathComponent("settings-license-render.png")
        )

        try renderPNG(
            ZStack {
                renderBackdrop.opacity(0.3)
                    .ignoresSafeArea()
                SaneAboutView(
                    appName: "SaneClip",
                    githubRepo: "SaneClip",
                    diagnosticsService: .shared,
                    licenses: previewAboutLicenses
                )
            }
                .preferredColorScheme(.dark)
                .frame(width: 1000, height: 760),
            size: CGSize(width: 1000, height: 760),
            to: outputDir.appendingPathComponent("settings-about-render.png")
        )

        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("settings-general-render.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("settings-shortcuts-render.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("settings-snippets-render.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("settings-sync-render.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("settings-sync-enabled-render.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("settings-storage-render.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("settings-license-render.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("settings-about-render.png").path))
    }

    @Test("SettingsModel round-trips excluded apps through fresh initialization")
    @MainActor
    func settingsModelExcludedAppsRoundTrip() {
        let settings = SettingsModel.shared
        let originalExcluded = settings.excludedApps
        defer { settings.excludedApps = originalExcluded }

        settings.excludedApps = ["com.test.one", "com.test.two"]

        let reloaded = SettingsModel()
        #expect(reloaded.excludedApps == ["com.test.one", "com.test.two"])
    }

    @MainActor
    private func renderPNG<Content: View>(_ view: Content, size: CGSize, to url: URL) throws {
        let controller = NSHostingController(rootView: view.frame(width: size.width, height: size.height))
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        window.backgroundColor = .windowBackgroundColor
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        controller.view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.35))

        let renderView = controller.view
        guard let bitmap = renderView.bitmapImageRepForCachingDisplay(in: renderView.bounds) else {
            Issue.record("Failed to render screenshot for \(url.lastPathComponent)")
            return
        }

        renderView.cacheDisplay(in: renderView.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            Issue.record("Failed to encode screenshot for \(url.lastPathComponent)")
            return
        }

        try png.write(to: url, options: .atomic)
        window.orderOut(nil)
    }

    private func screenshotOutputDirectory() -> String? {
        if let rawOutputDir = ProcessInfo.processInfo.environment["SANECLIP_SCREENSHOT_DIR"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !rawOutputDir.isEmpty
        {
            return rawOutputDir
        }

        if let hintedOutputDir = try? String(contentsOf: screenshotOutputHintFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !hintedOutputDir.isEmpty
        {
            return hintedOutputDir
        }

        return nil
    }
}
