import AppKit
import CloudKit
#if !APP_STORE
    import Sparkle
#endif
import SaneUI
import SwiftUI
import Testing
@testable import SaneClip

struct SaneClipTests {
    private let screenshotOutputHintFile = URL(fileURLWithPath: "/tmp/saneclip_screenshot_dir.txt")
    private let renderBackdrop = Color(red: 0.06, green: 0.10, blue: 0.18)
    private let appStoreCanvasSize = CGSize(width: 1440, height: 900)

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

        #expect(settingsSource.contains("SaneSettingsContainer(defaultTab: .general, selection: $selectedTab)"))
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
        guard ProcessInfo.processInfo.environment["SANECLIP_RENDER_SETTINGS_SHOTS"] == "1"
        else {
            return
        }

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
        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("settings-storage-render.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("settings-license-render.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("settings-about-render.png").path))
    }

    @Test("Render App Store macOS screenshots when requested")
    @MainActor
    func renderAppStoreMacScreenshots() throws {
        guard let rawOutputDir = screenshotOutputDirectory()
        else {
            return
        }

        let outputDir = URL(
            fileURLWithPath: NSString(string: rawOutputDir).expandingTildeInPath,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let licenseService = LicenseService(
            appName: "SaneClip",
            purchaseBackend: .appStore(productID: "com.saneclip.app.pro.unlock")
        )
        let clipboardManager = seedAppStoreScreenshotState()
        let originalSharedClipboardManager = ClipboardManager.shared
        let snippetManager = SnippetManager.shared
        let originalSnippets = snippetManager.snippets
        defer {
            ClipboardManager.shared = originalSharedClipboardManager
            snippetManager.snippets = originalSnippets
        }

        ClipboardManager.shared = clipboardManager
        snippetManager.snippets = [
            Snippet(
                name: "Follow-up Email",
                template: "Thanks again for the time today. I attached the recap and next steps below.",
                category: "Work",
                lastUsedAt: Date().addingTimeInterval(-1_800),
                useCount: 14
            ),
            Snippet(
                name: "Shipping Update",
                template: "Your order is packed and leaves the warehouse this afternoon.",
                category: "Support",
                lastUsedAt: Date().addingTimeInterval(-3_600),
                useCount: 8
            ),
            Snippet(
                name: "Date Stamp",
                template: "{{date}}",
                category: "Utility",
                lastUsedAt: Date().addingTimeInterval(-7_200),
                useCount: 20
            )
        ]

        try renderPNG(
            appStoreHistoryShowcase(clipboardManager: clipboardManager, licenseService: licenseService)
                .frame(width: appStoreCanvasSize.width, height: appStoreCanvasSize.height),
            size: appStoreCanvasSize,
            to: outputDir.appendingPathComponent("appstore-macos-history.png")
        )

        try renderPNG(
            appStoreSettingsShowcase(licenseService: licenseService, tab: .general)
                .frame(width: appStoreCanvasSize.width, height: appStoreCanvasSize.height),
            size: appStoreCanvasSize,
            to: outputDir.appendingPathComponent("appstore-macos-general.png")
        )

        try renderPNG(
            appStoreSettingsShowcase(licenseService: licenseService, tab: .shortcuts)
                .frame(width: appStoreCanvasSize.width, height: appStoreCanvasSize.height),
            size: appStoreCanvasSize,
            to: outputDir.appendingPathComponent("appstore-macos-shortcuts.png")
        )

        try renderPNG(
            appStoreSettingsShowcase(licenseService: licenseService, tab: .snippets)
                .frame(width: appStoreCanvasSize.width, height: appStoreCanvasSize.height),
            size: appStoreCanvasSize,
            to: outputDir.appendingPathComponent("appstore-macos-snippets.png")
        )

        try renderPNG(
            appStoreSettingsShowcase(licenseService: licenseService, tab: .license)
                .frame(width: appStoreCanvasSize.width, height: appStoreCanvasSize.height),
            size: appStoreCanvasSize,
            to: outputDir.appendingPathComponent("appstore-macos-license.png")
        )

        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("appstore-macos-history.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("appstore-macos-general.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("appstore-macos-shortcuts.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("appstore-macos-snippets.png").path))
        #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent("appstore-macos-license.png").path))
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
        let content = view.frame(width: size.width, height: size.height)
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = CGRect(origin: .zero, size: size)
        hostingView.setFrameSize(size)
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        guard let fallbackBitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            Issue.record("Failed to render screenshot for \(url.lastPathComponent)")
            return
        }

        hostingView.cacheDisplay(in: hostingView.bounds, to: fallbackBitmap)
        guard let fallbackPNG = fallbackBitmap.representation(using: .png, properties: [:]) else {
            Issue.record("Failed to encode screenshot for \(url.lastPathComponent)")
            return
        }

        try fallbackPNG.write(to: url, options: .atomic)
    }

    @MainActor
    private func seedAppStoreScreenshotState() -> ClipboardManager {
        let now = Date()
        let clipboardManager = ClipboardManager()
        clipboardManager.licenseService = LicenseService(
            appName: "SaneClip",
            purchaseBackend: .appStore(productID: "com.saneclip.app.pro.unlock")
        )
        clipboardManager.pinnedItems = [
            ClipboardItem(
                content: .text("https://saneapps.com/saneclip"),
                timestamp: now.addingTimeInterval(-1_200),
                sourceAppBundleID: "com.apple.Safari",
                sourceAppName: "Safari",
                pasteCount: 3,
                title: "SaneClip for Mac",
                collection: "Links"
            )
        ]
        clipboardManager.history = [
            ClipboardItem(
                content: .text("Meeting recap: ship the clipboard search update on Friday and keep the macOS build aligned with iPhone."),
                timestamp: now.addingTimeInterval(-2_400),
                sourceAppBundleID: "com.apple.Notes",
                sourceAppName: "Notes",
                pasteCount: 2,
                collection: "Work"
            ),
            ClipboardItem(
                content: .text("func presentShareSheet() { print(\"Ready to share the latest build\") }"),
                timestamp: now.addingTimeInterval(-4_800),
                sourceAppBundleID: "com.apple.dt.Xcode",
                sourceAppName: "Xcode",
                pasteCount: 1,
                title: "Share Sheet Helper",
                collection: "Code"
            ),
            ClipboardItem(
                content: .text("Shipping update: your replacement cable is out for delivery and should arrive before 8 PM."),
                timestamp: now.addingTimeInterval(-7_200),
                sourceAppBundleID: "com.apple.Mail",
                sourceAppName: "Mail",
                pasteCount: 4,
                collection: "Support"
            ),
            ClipboardItem(
                content: .text("https://developer.apple.com/app-store/review/guidelines/"),
                timestamp: now.addingTimeInterval(-9_600),
                sourceAppBundleID: "com.apple.Safari",
                sourceAppName: "Safari",
                pasteCount: 1,
                collection: "Links"
            )
        ]
        return clipboardManager
    }

    @MainActor
    private func appStoreHistoryShowcase(
        clipboardManager: ClipboardManager,
        licenseService: LicenseService
    ) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    renderBackdrop.opacity(0.96),
                    Color(red: 0.09, green: 0.13, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Search clipboard history...")
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.06))

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let pinned = clipboardManager.pinnedItems.first {
                            Text("Pinned")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.92))
                            ClipboardItemRow(
                                item: pinned,
                                isPinned: true,
                                clipboardManager: clipboardManager,
                                licenseService: licenseService
                            )
                        }

                        Text("Recent")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.92))

                        ForEach(clipboardManager.history.prefix(4)) { item in
                            ClipboardItemRow(
                                item: item,
                                isPinned: false,
                                clipboardManager: clipboardManager,
                                licenseService: licenseService
                            )
                        }
                    }
                    .padding(16)
                }

                HStack {
                    Text("50 items")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    Label("Clear All", systemImage: "trash")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.06))
            }
            .frame(width: 540, height: 820)
            .preferredColorScheme(.dark)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.black.opacity(0.24))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 30, x: 0, y: 20)
        }
    }

    @MainActor
    private func appStoreSettingsShowcase(
        licenseService: LicenseService,
        tab: SettingsView.SettingsTab
    ) -> some View {
        ZStack {
            renderBackdrop
                .ignoresSafeArea()

            HStack(spacing: 0) {
                screenshotSidebar(selectedTab: tab)
                    .frame(width: 260)
                    .padding(18)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)

                screenshotSettingsContent(for: tab, licenseService: licenseService)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(28)
            }
            .frame(width: 1180, height: 780)
            .background(Color(red: 0.10, green: 0.12, blue: 0.18))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.32), radius: 24, x: 0, y: 18)
        }
    }

    @ViewBuilder
    private func screenshotSettingsContent(
        for tab: SettingsView.SettingsTab,
        licenseService: LicenseService
    ) -> some View {
        switch tab {
        case .general:
            VStack(alignment: .leading, spacing: 18) {
                screenshotSection("Startup") {
                    screenshotToggleRow("Start automatically at login", isOn: false)
                    screenshotToggleRow("Show app in Dock", isOn: true)
                }
                screenshotSection("Appearance") {
                    screenshotValueRow("Menu Bar Icon", value: "List")
                    screenshotToggleRow("Play sound when copying", isOn: false)
                }
                screenshotSection("Security") {
                    screenshotToggleRow("Detect & skip passwords", isOn: true)
                    screenshotToggleRow("Require Touch ID to view history", isOn: false)
                    screenshotButtonRow("Excluded Apps", buttonTitle: "Add App...")
                }
            }
        case .shortcuts:
            VStack(alignment: .leading, spacing: 18) {
                screenshotSection("History") {
                    screenshotShortcutRow("Show clipboard history", shortcut: "⌘⇧V")
                    screenshotShortcutRow("Paste as plain text", shortcut: "⌘⌥V")
                    screenshotShortcutRow("Open at cursor", shortcut: "⌃⌥V")
                }
                screenshotSection("Quick Paste") {
                    screenshotShortcutRow("Paste first item", shortcut: "⌃1")
                    screenshotShortcutRow("Paste second item", shortcut: "⌃2")
                    screenshotShortcutRow("Paste third item", shortcut: "⌃3")
                }
            }
        case .snippets:
            VStack(alignment: .leading, spacing: 18) {
                screenshotSection("Snippets") {
                    screenshotSnippetRow(name: "Follow-up Email", detail: "Thanks again for the time today. I attached the recap and next steps below.", tag: "Work")
                    screenshotSnippetRow(name: "Shipping Update", detail: "Your order is packed and leaves the warehouse this afternoon.", tag: "Support")
                    screenshotSnippetRow(name: "Date Stamp", detail: "{{date}}", tag: "Utility")
                }
                HStack {
                    Text("3 snippets")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.86))
                    Spacer()
                    screenshotPrimaryButton("Add Snippet")
                }
            }
        case .sync:
            screenshotSection("iCloud Sync") {
                screenshotToggleRow("Sync clipboard history across your Apple devices", isOn: true)
                screenshotValueRow("Status", value: "Idle")
                screenshotValueRow("Connected Devices", value: "MacBook Pro, iPhone 16 Pro")
            }
        case .storage:
            screenshotSection("Storage") {
                screenshotValueRow("Total Items", value: "50")
                screenshotValueRow("Pinned", value: "4")
                screenshotValueRow("Storage", value: "184 KB")
            }
        case .license:
            VStack(alignment: .leading, spacing: 18) {
                screenshotSection("Unlock Pro") {
                    screenshotValueRow("One-time unlock", value: "$6.99")
                    screenshotValueRow("Includes", value: "Unlimited history, snippets, paste tools, Touch ID lock")
                }
                HStack(spacing: 12) {
                    screenshotPrimaryButton("Unlock Pro")
                    screenshotSecondaryButton("Restore Purchases")
                }
                Text("The App Store build uses StoreKit only.")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.82))
            }
        case .about:
            screenshotSection("About") {
                screenshotValueRow("Version", value: "2.2.11")
                screenshotValueRow("Privacy", value: "Private clipboard history with iCloud sync")
            }
        }
    }

    private func screenshotSidebar(selectedTab: SettingsView.SettingsTab) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SaneClip Settings")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .padding(.bottom, 10)

            ForEach(Array(SettingsView.SettingsTab.allCases), id: \.id) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.icon)
                        .frame(width: 18)
                    Text(item.title)
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(item == selectedTab ? Color.blue.opacity(0.78) : Color.clear)
                )
            }

            Spacer()
        }
    }

    private func screenshotSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func screenshotToggleRow(_ title: String, isOn: Bool) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            screenshotToggle(isOn: isOn)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private func screenshotValueRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.86))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private func screenshotButtonRow(_ title: String, buttonTitle: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            screenshotSecondaryButton(buttonTitle)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private func screenshotShortcutRow(_ title: String, shortcut: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Text(shortcut)
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.2))
                )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private func screenshotSnippetRow(name: String, detail: String, tag: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(tag)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.28))
                    .clipShape(Capsule())
            }
            Text(detail)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private func screenshotToggle(isOn: Bool) -> some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? Color.blue : Color.white.opacity(0.18))
                .frame(width: 56, height: 32)
            Circle()
                .fill(.white)
                .frame(width: 26, height: 26)
                .padding(3)
        }
    }

    private func screenshotPrimaryButton(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue)
            )
    }

    private func screenshotSecondaryButton(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
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
