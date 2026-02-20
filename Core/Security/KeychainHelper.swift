import Foundation
import Security

/// Thread-safe Keychain wrapper for storing secrets (webhook credentials, encryption keys)
struct KeychainHelper: Sendable {
    static let service = Bundle.main.bundleIdentifier ?? "com.saneclip.app"

    // MARK: - Account Constants

    static let webhookSecretAccount = "webhook-secret"
    static let historyEncryptionKeyAccount = "history-encryption-key"

    // MARK: - Data Operations

    /// Saves data to Keychain (upserts: deletes existing then adds)
    @discardableResult
    static func save(data: Data, account: String) -> Bool {
        if isKeychainBypassed {
            fallbackDefaults.set(data.base64EncodedString(), forKey: fallbackKey(account))
            return true
        }

        // Delete any existing item first
        delete(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Loads data from Keychain
    static func load(account: String) -> Data? {
        if isKeychainBypassed {
            guard let encoded = fallbackDefaults.string(forKey: fallbackKey(account)),
                  let data = Data(base64Encoded: encoded)
            else { return nil }
            return data
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// Deletes an item from Keychain
    @discardableResult
    static func delete(account: String) -> Bool {
        if isKeychainBypassed {
            fallbackDefaults.removeObject(forKey: fallbackKey(account))
            return true
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Checks whether an item exists in Keychain
    static func exists(account: String) -> Bool {
        if isKeychainBypassed {
            return fallbackDefaults.string(forKey: fallbackKey(account)) != nil
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - String Convenience

    /// Saves a UTF-8 string to Keychain
    @discardableResult
    static func save(string: String, account: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return save(data: data, account: account)
    }

    /// Loads a UTF-8 string from Keychain
    static func loadString(account: String) -> String? {
        guard let data = load(account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static var isKeychainBypassed: Bool {
#if DEBUG
        if ProcessInfo.processInfo.environment["SANEAPPS_ENABLE_KEYCHAIN_IN_DEBUG"] != "1" {
            return true
        }
#endif
        return ProcessInfo.processInfo.environment["SANEAPPS_DISABLE_KEYCHAIN"] == "1"
            || ProcessInfo.processInfo.arguments.contains("--sane-no-keychain")
    }

    private static var fallbackDefaults: UserDefaults {
        UserDefaults(suiteName: "com.saneclip.no-keychain") ?? .standard
    }

    private static func fallbackKey(_ account: String) -> String {
        "sane.no-keychain.\(service).\(account)"
    }
}
