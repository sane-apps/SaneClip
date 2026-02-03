import Foundation
import Testing
@testable import SaneClip

// MARK: - URL Scheme Security Tests

struct URLSchemeSecurityTests {

    @Test("URL scheme parses copy command")
    func testParseCommandCopy() {
        let url = URL(string: "saneclip://copy?text=Hello%20World")!
        let command = URLSchemeHandler.parseCommand(url)
        #expect(command == .copy(text: "Hello World"))
    }

    @Test("URL scheme parses paste command")
    func testParseCommandPaste() {
        let url = URL(string: "saneclip://paste?index=3")!
        let command = URLSchemeHandler.parseCommand(url)
        #expect(command == .paste(index: 3))
    }

    @Test("URL scheme parses search command")
    func testParseCommandSearch() {
        let url = URL(string: "saneclip://search?q=hello")!
        let command = URLSchemeHandler.parseCommand(url)
        #expect(command == .search(query: "hello"))
    }

    @Test("URL scheme parses snippet command")
    func testParseCommandSnippet() {
        let url = URL(string: "saneclip://snippet?name=Email%20Sig")!
        let command = URLSchemeHandler.parseCommand(url)
        #expect(command == .snippet(name: "Email Sig", values: [:]))
    }

    @Test("URL scheme parses clear command")
    func testParseCommandClear() {
        let url = URL(string: "saneclip://clear")!
        let command = URLSchemeHandler.parseCommand(url)
        #expect(command == .clear)
    }

    @Test("URL scheme parses export command")
    func testParseCommandExport() {
        let url = URL(string: "saneclip://export")!
        let command = URLSchemeHandler.parseCommand(url)
        #expect(command == .export)
    }

    @Test("URL scheme parses history command")
    func testParseCommandHistory() {
        let url = URL(string: "saneclip://history")!
        let command = URLSchemeHandler.parseCommand(url)
        #expect(command == .history)
    }

    @Test("URL scheme returns nil for invalid URLs")
    func testParseCommandInvalid() {
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
    func testDestructiveCommandsRequireConfirmation() {
        #expect(URLSchemeCommand.copy(text: "x").requiresConfirmation == true)
        #expect(URLSchemeCommand.paste(index: 0).requiresConfirmation == true)
        #expect(URLSchemeCommand.snippet(name: "x", values: [:]).requiresConfirmation == true)
        #expect(URLSchemeCommand.clear.requiresConfirmation == true)
    }

    @Test("Read-only commands do not require confirmation")
    func testReadOnlyCommandsNoConfirmation() {
        #expect(URLSchemeCommand.search(query: "x").requiresConfirmation == false)
        #expect(URLSchemeCommand.export.requiresConfirmation == false)
        #expect(URLSchemeCommand.history.requiresConfirmation == false)
    }
}

// MARK: - Webhook Security Tests

struct WebhookSecurityTests {

    @Test("Webhook rejects plain HTTP endpoints")
    func testWebhookRejectsHTTP() {
        let httpURL = URL(string: "http://api.example.com/webhook")!
        #expect(WebhookService.isSecureEndpoint(httpURL) == false)
    }

    @Test("Webhook accepts HTTPS endpoints")
    func testWebhookAcceptsHTTPS() {
        let httpsURL = URL(string: "https://api.example.com/webhook")!
        #expect(WebhookService.isSecureEndpoint(httpsURL) == true)
    }

    @Test("Webhook allows HTTP localhost for development")
    func testWebhookAllowsLocalhostHTTP() {
        let localhost = URL(string: "http://localhost:8080/hook")!
        #expect(WebhookService.isSecureEndpoint(localhost) == true)

        let ip4Loopback = URL(string: "http://127.0.0.1:3000/hook")!
        #expect(WebhookService.isSecureEndpoint(ip4Loopback) == true)

        let ip6Loopback = URL(string: "http://[::1]:3000/hook")!
        #expect(WebhookService.isSecureEndpoint(ip6Loopback) == true)
    }

    @Test("Webhook rejects file:// scheme")
    func testWebhookRejectsFileScheme() {
        let fileURL = URL(string: "file:///etc/passwd")!
        #expect(WebhookService.isSecureEndpoint(fileURL) == false)
    }

    @Test("Webhook rejects custom schemes")
    func testWebhookRejectsCustomScheme() {
        let customURL = URL(string: "ftp://example.com/hook")!
        #expect(WebhookService.isSecureEndpoint(customURL) == false)
    }
}

// MARK: - Keychain Tests

struct KeychainTests {

    @Test("Keychain stores and retrieves strings")
    func testKeychainStringRoundTrip() {
        let testAccount = "test-keychain-\(UUID().uuidString)"
        defer { KeychainHelper.delete(account: testAccount) }

        let saved = KeychainHelper.save(string: "secret-value", account: testAccount)
        #expect(saved == true)

        let loaded = KeychainHelper.loadString(account: testAccount)
        #expect(loaded == "secret-value")
    }

    @Test("Keychain stores and retrieves data")
    func testKeychainDataRoundTrip() {
        let testAccount = "test-keychain-data-\(UUID().uuidString)"
        defer { KeychainHelper.delete(account: testAccount) }

        let testData = Data([0x01, 0x02, 0x03, 0xFF])
        let saved = KeychainHelper.save(data: testData, account: testAccount)
        #expect(saved == true)

        let loaded = KeychainHelper.load(account: testAccount)
        #expect(loaded == testData)
    }

    @Test("Keychain delete removes item")
    func testKeychainDelete() {
        let testAccount = "test-keychain-del-\(UUID().uuidString)"

        KeychainHelper.save(string: "to-delete", account: testAccount)
        #expect(KeychainHelper.exists(account: testAccount) == true)

        KeychainHelper.delete(account: testAccount)
        #expect(KeychainHelper.exists(account: testAccount) == false)
    }

    @Test("Keychain load returns nil for missing item")
    func testKeychainLoadMissing() {
        let loaded = KeychainHelper.loadString(account: "nonexistent-\(UUID().uuidString)")
        #expect(loaded == nil)
    }

    @Test("Keychain upsert overwrites existing item")
    func testKeychainUpsert() {
        let testAccount = "test-keychain-upsert-\(UUID().uuidString)"
        defer { KeychainHelper.delete(account: testAccount) }

        KeychainHelper.save(string: "original", account: testAccount)
        KeychainHelper.save(string: "updated", account: testAccount)

        let loaded = KeychainHelper.loadString(account: testAccount)
        #expect(loaded == "updated")
    }
}

// MARK: - Encryption Tests

struct EncryptionTests {

    @Test("Encryption round-trip preserves data")
    func testEncryptionRoundTrip() throws {
        let original = Data("Hello, encrypted world! This is test data.".utf8)

        let encrypted = try HistoryEncryption.encrypt(original)
        let decrypted = try HistoryEncryption.decrypt(encrypted)

        #expect(decrypted == original)
    }

    @Test("Encrypted output differs from input")
    func testEncryptedDiffersFromPlaintext() throws {
        let original = Data("Some clipboard history JSON".utf8)
        let encrypted = try HistoryEncryption.encrypt(original)

        #expect(encrypted != original)
    }

    @Test("Detects plaintext JSON vs encrypted data")
    func testIsEncryptedDetection() {
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
    func testEmptyDataNotEncrypted() {
        let empty = Data()
        #expect(HistoryEncryption.isEncrypted(empty) == false)
    }
}
