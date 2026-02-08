import Foundation
@testable import SaneClip
import Testing

// MARK: - URL Scheme Security Tests

struct URLSchemeSecurityTests {
    @Test("URL scheme parses copy command")
    func parseCommandCopy() {
        let url = URL(string: "saneclip://copy?text=Hello%20World")!
        let command = URLSchemeHandler.parseCommand(url)
        #expect(command == .copy(text: "Hello World"))
    }

    @Test("URL scheme parses paste command")
    func parseCommandPaste() {
        let url = URL(string: "saneclip://paste?index=3")!
        let command = URLSchemeHandler.parseCommand(url)
        #expect(command == .paste(index: 3))
    }

    @Test("URL scheme parses search command")
    func parseCommandSearch() {
        let url = URL(string: "saneclip://search?q=hello")!
        let command = URLSchemeHandler.parseCommand(url)
        #expect(command == .search(query: "hello"))
    }

    @Test("URL scheme parses snippet command")
    func parseCommandSnippet() {
        let url = URL(string: "saneclip://snippet?name=Email%20Sig")!
        let command = URLSchemeHandler.parseCommand(url)
        #expect(command == .snippet(name: "Email Sig", values: [:]))
    }

    @Test("URL scheme parses clear command")
    func parseCommandClear() {
        let url = URL(string: "saneclip://clear")!
        let command = URLSchemeHandler.parseCommand(url)
        #expect(command == .clear)
    }

    @Test("URL scheme parses export command")
    func parseCommandExport() {
        let url = URL(string: "saneclip://export")!
        let command = URLSchemeHandler.parseCommand(url)
        #expect(command == .export)
    }

    @Test("URL scheme parses history command")
    func parseCommandHistory() {
        let url = URL(string: "saneclip://history")!
        let command = URLSchemeHandler.parseCommand(url)
        #expect(command == .history)
    }

    @Test("URL scheme returns nil for invalid URLs")
    func parseCommandInvalid() {
        let badScheme = URL(string: "https://copy?text=hello")!
        #expect(URLSchemeHandler.parseCommand(badScheme) == nil)

        let noHost = URL(string: "saneclip:///")!
        #expect(URLSchemeHandler.parseCommand(noHost) == nil)

        let unknownCommand = URL(string: "saneclip://delete?id=123")!
        #expect(URLSchemeHandler.parseCommand(unknownCommand) == nil)

        let missingParam = URL(string: "saneclip://copy")!
        #expect(URLSchemeHandler.parseCommand(missingParam) == nil)

        let negativeIndex = URL(string: "saneclip://paste?index=-1")!
        #expect(URLSchemeHandler.parseCommand(negativeIndex) == nil)
    }

    @Test("Destructive commands require confirmation")
    func destructiveCommandsRequireConfirmation() {
        #expect(URLSchemeCommand.copy(text: "x").requiresConfirmation == true)
        #expect(URLSchemeCommand.paste(index: 0).requiresConfirmation == true)
        #expect(URLSchemeCommand.snippet(name: "x", values: [:]).requiresConfirmation == true)
        #expect(URLSchemeCommand.clear.requiresConfirmation == true)
    }

    @Test("Read-only commands do not require confirmation")
    func readOnlyCommandsNoConfirmation() {
        #expect(URLSchemeCommand.search(query: "x").requiresConfirmation == false)
        #expect(URLSchemeCommand.export.requiresConfirmation == false)
        #expect(URLSchemeCommand.history.requiresConfirmation == false)
    }
}

// MARK: - Webhook Security Tests

struct WebhookSecurityTests {
    @Test("Webhook rejects plain HTTP endpoints")
    func webhookRejectsHTTP() {
        let httpURL = URL(string: "http://api.example.com/webhook")!
        #expect(WebhookService.isSecureEndpoint(httpURL) == false)
    }

    @Test("Webhook accepts HTTPS endpoints")
    func webhookAcceptsHTTPS() {
        let httpsURL = URL(string: "https://api.example.com/webhook")!
        #expect(WebhookService.isSecureEndpoint(httpsURL) == true)
    }

    @Test("Webhook allows HTTP localhost for development")
    func webhookAllowsLocalhostHTTP() {
        let localhost = URL(string: "http://localhost:8080/hook")!
        #expect(WebhookService.isSecureEndpoint(localhost) == true)

        let ip4Loopback = URL(string: "http://127.0.0.1:3000/hook")!
        #expect(WebhookService.isSecureEndpoint(ip4Loopback) == true)

        let ip6Loopback = URL(string: "http://[::1]:3000/hook")!
        #expect(WebhookService.isSecureEndpoint(ip6Loopback) == true)
    }

    @Test("Webhook rejects file:// scheme")
    func webhookRejectsFileScheme() {
        let fileURL = URL(string: "file:///etc/passwd")!
        #expect(WebhookService.isSecureEndpoint(fileURL) == false)
    }

    @Test("Webhook rejects custom schemes")
    func webhookRejectsCustomScheme() {
        let customURL = URL(string: "ftp://example.com/hook")!
        #expect(WebhookService.isSecureEndpoint(customURL) == false)
    }
}

// MARK: - Keychain Tests

struct KeychainTests {
    @Test("Keychain stores and retrieves strings")
    func keychainStringRoundTrip() {
        let testAccount = "test-keychain-\(UUID().uuidString)"
        defer { KeychainHelper.delete(account: testAccount) }

        let saved = KeychainHelper.save(string: "secret-value", account: testAccount)
        #expect(saved == true)

        let loaded = KeychainHelper.loadString(account: testAccount)
        #expect(loaded == "secret-value")
    }

    @Test("Keychain stores and retrieves data")
    func keychainDataRoundTrip() {
        let testAccount = "test-keychain-data-\(UUID().uuidString)"
        defer { KeychainHelper.delete(account: testAccount) }

        let testData = Data([0x01, 0x02, 0x03, 0xFF])
        let saved = KeychainHelper.save(data: testData, account: testAccount)
        #expect(saved == true)

        let loaded = KeychainHelper.load(account: testAccount)
        #expect(loaded == testData)
    }

    @Test("Keychain delete removes item")
    func keychainDelete() {
        let testAccount = "test-keychain-del-\(UUID().uuidString)"

        KeychainHelper.save(string: "to-delete", account: testAccount)
        #expect(KeychainHelper.exists(account: testAccount) == true)

        KeychainHelper.delete(account: testAccount)
        #expect(KeychainHelper.exists(account: testAccount) == false)
    }

    @Test("Keychain load returns nil for missing item")
    func keychainLoadMissing() {
        let loaded = KeychainHelper.loadString(account: "nonexistent-\(UUID().uuidString)")
        #expect(loaded == nil)
    }

    @Test("Keychain upsert overwrites existing item")
    func keychainUpsert() {
        let testAccount = "test-keychain-upsert-\(UUID().uuidString)"
        defer { KeychainHelper.delete(account: testAccount) }

        KeychainHelper.save(string: "original", account: testAccount)
        KeychainHelper.save(string: "updated", account: testAccount)

        let loaded = KeychainHelper.loadString(account: testAccount)
        #expect(loaded == "updated")
    }
}

// MARK: - Shared Clipboard Item Tests

struct SharedClipboardItemTests {
    @Test("SharedClipboardItem text content encodes and decodes")
    func textContentCodable() throws {
        let item = SharedClipboardItem(
            content: .text("Hello from Mac"),
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            sourceAppBundleID: "com.apple.Safari",
            sourceAppName: "Safari",
            pasteCount: 3,
            deviceId: "Stephan's Mac",
            deviceName: "Mac"
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(SharedClipboardItem.self, from: data)

        #expect(decoded.id == item.id)
        #expect(decoded.preview == "Hello from Mac")
        #expect(decoded.sourceAppBundleID == "com.apple.Safari")
        #expect(decoded.sourceAppName == "Safari")
        #expect(decoded.pasteCount == 3)
        #expect(decoded.deviceId == "Stephan's Mac")
        #expect(decoded.deviceName == "Mac")
    }

    @Test("SharedClipboardItem image content encodes and decodes")
    func imageContentCodable() throws {
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG header bytes
        let item = SharedClipboardItem(
            content: .imageData(imageData, width: 100, height: 50),
            deviceId: "iPhone",
            deviceName: "iPhone"
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(SharedClipboardItem.self, from: data)

        #expect(decoded.preview == "[Image]")
        if case let .imageData(decodedData, width, height) = decoded.content {
            #expect(decodedData == imageData)
            #expect(width == 100)
            #expect(height == 50)
        } else {
            #expect(Bool(false), "Expected imageData content")
        }
    }

    @Test("SharedClipboardItem preview truncates long text")
    func previewTruncation() {
        let longText = String(repeating: "x", count: 200)
        let item = SharedClipboardItem(content: .text(longText))

        #expect(item.preview.count == 103) // 100 + "..."
        #expect(item.preview.hasSuffix("..."))
    }

    @Test("SharedClipboardItem detects URLs")
    func uRLDetection() {
        let urlItem = SharedClipboardItem(content: .text("https://saneclip.com"))
        #expect(urlItem.isURL == true)

        let textItem = SharedClipboardItem(content: .text("just some text"))
        #expect(textItem.isURL == false)
    }

    @Test("SharedClipboardItem detects code")
    func codeDetection() {
        let codeItem = SharedClipboardItem(content: .text("func hello() { return true }"))
        #expect(codeItem.isCode == true)

        let textItem = SharedClipboardItem(content: .text("shopping list: milk, bread"))
        #expect(textItem.isCode == false)
    }

    @Test("SharedClipboardContent text round-trip preserves content")
    func sharedContentTextCodable() throws {
        let content = SharedClipboardContent.text("Test clipboard text")
        let data = try JSONEncoder().encode(content)
        let decoded = try JSONDecoder().decode(SharedClipboardContent.self, from: data)

        if case let .text(text) = decoded {
            #expect(text == "Test clipboard text")
        } else {
            #expect(Bool(false), "Expected text content")
        }
    }

    @Test("SharedClipboardContent image round-trip preserves content")
    func sharedContentImageCodable() throws {
        let imgData = Data(repeating: 0xAB, count: 64)
        let content = SharedClipboardContent.imageData(imgData, width: 320, height: 240)
        let data = try JSONEncoder().encode(content)
        let decoded = try JSONDecoder().decode(SharedClipboardContent.self, from: data)

        if case let .imageData(decodedData, w, h) = decoded {
            #expect(decodedData == imgData)
            #expect(w == 320)
            #expect(h == 240)
        } else {
            #expect(Bool(false), "Expected imageData content")
        }
    }

    @Test("Encryption round-trip works for SharedClipboardContent")
    func encryptedContentRoundTrip() throws {
        let content = SharedClipboardContent.text("Secret clipboard data")
        let contentData = try JSONEncoder().encode(content)

        let encrypted = try HistoryEncryption.encrypt(contentData)
        #expect(encrypted != contentData)

        let decrypted = try HistoryEncryption.decrypt(encrypted)
        let decoded = try JSONDecoder().decode(SharedClipboardContent.self, from: decrypted)

        if case let .text(text) = decoded {
            #expect(text == "Secret clipboard data")
        } else {
            #expect(Bool(false), "Expected text content after decrypt")
        }
    }
}

// MARK: - Encryption Tests

struct EncryptionTests {
    @Test("Encryption round-trip preserves data")
    func encryptionRoundTrip() throws {
        let original = Data("Hello, encrypted world! This is test data.".utf8)

        let encrypted = try HistoryEncryption.encrypt(original)
        let decrypted = try HistoryEncryption.decrypt(encrypted)

        #expect(decrypted == original)
    }

    @Test("Encrypted output differs from input")
    func encryptedDiffersFromPlaintext() throws {
        let original = Data("Some clipboard history JSON".utf8)
        let encrypted = try HistoryEncryption.encrypt(original)

        #expect(encrypted != original)
    }

    @Test("Detects plaintext JSON vs encrypted data")
    func isEncryptedDetection() {
        // JSON array
        let jsonArray = Data("[{\"id\":\"123\"}]".utf8)
        #expect(HistoryEncryption.isEncrypted(jsonArray) == false)

        // JSON object
        let jsonObject = Data("{\"key\":\"value\"}".utf8)
        #expect(HistoryEncryption.isEncrypted(jsonObject) == false)

        // Random bytes (simulating encrypted data)
        let encrypted = Data([0xA0, 0xB1, 0xC2, 0xD3, 0xE4])
        #expect(HistoryEncryption.isEncrypted(encrypted) == true)
    }

    @Test("Empty data is not considered encrypted")
    func emptyDataNotEncrypted() {
        let empty = Data()
        #expect(HistoryEncryption.isEncrypted(empty) == false)
    }
}
