import AppKit
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

        var pasteIntent = PasteSnippetIntent()
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

}
