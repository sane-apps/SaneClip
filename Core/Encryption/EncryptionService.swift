import Foundation
import CryptoKit
import Security

/// Errors that can occur during encryption operations
enum EncryptionError: Error, LocalizedError {
    case keyGenerationFailed
    case keychainStoreFailed(OSStatus)
    case keychainRetrieveFailed(OSStatus)
    case encryptionFailed
    case decryptionFailed
    case invalidData

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate encryption key"
        case .keychainStoreFailed(let status):
            return "Failed to store key in Keychain (status: \(status))"
        case .keychainRetrieveFailed(let status):
            return "Failed to retrieve key from Keychain (status: \(status))"
        case .encryptionFailed:
            return "Encryption operation failed"
        case .decryptionFailed:
            return "Decryption operation failed"
        case .invalidData:
            return "Invalid or corrupted data"
        }
    }
}

/// Service providing AES-256-GCM encryption for sensitive clipboard data
/// Keys are stored securely in the macOS Keychain
final class EncryptionService: Sendable {

    /// Shared singleton instance
    static let shared = EncryptionService()

    /// Keychain service identifier for the encryption key
    private let keychainService = "com.saneclip.encryption"
    private let keychainAccount = "sync-key"

    private init() {}

    // MARK: - Public API

    /// Encrypts a string using AES-256-GCM
    /// - Parameter plaintext: The text to encrypt
    /// - Returns: A tuple containing the ciphertext and nonce
    /// - Throws: EncryptionError if encryption fails
    func encrypt(_ plaintext: String) throws -> (ciphertext: Data, nonce: Data) {
        let key = try getOrCreateKey()
        let plaintextData = Data(plaintext.utf8)

        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(plaintextData, using: key, nonce: nonce)

        // Combine ciphertext and authentication tag
        let combined = sealedBox.ciphertext + sealedBox.tag
        return (combined, Data(nonce))
    }

    /// Decrypts data that was encrypted with encrypt()
    /// - Parameters:
    ///   - ciphertext: The encrypted data (ciphertext + tag)
    ///   - nonce: The nonce used during encryption
    /// - Returns: The decrypted string
    /// - Throws: EncryptionError if decryption fails
    func decrypt(_ ciphertext: Data, nonce: Data) throws -> String {
        let key = try getOrCreateKey()

        guard ciphertext.count > 16 else {
            throw EncryptionError.invalidData
        }

        let gcmNonce = try AES.GCM.Nonce(data: nonce)

        // Split ciphertext and tag (tag is last 16 bytes)
        let tagLength = 16
        let actualCiphertext = ciphertext.dropLast(tagLength)
        let tag = ciphertext.suffix(tagLength)

        let sealedBox = try AES.GCM.SealedBox(
            nonce: gcmNonce,
            ciphertext: actualCiphertext,
            tag: tag
        )

        let decryptedData = try AES.GCM.open(sealedBox, using: key)

        guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed
        }

        return decryptedString
    }

    /// Encrypts data using AES-256-GCM
    /// - Parameter data: The data to encrypt
    /// - Returns: A tuple containing the ciphertext and nonce
    func encryptData(_ data: Data) throws -> (ciphertext: Data, nonce: Data) {
        let key = try getOrCreateKey()
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
        let combined = sealedBox.ciphertext + sealedBox.tag
        return (combined, Data(nonce))
    }

    /// Decrypts data that was encrypted with encryptData()
    /// - Parameters:
    ///   - ciphertext: The encrypted data (ciphertext + tag)
    ///   - nonce: The nonce used during encryption
    /// - Returns: The decrypted data
    func decryptData(_ ciphertext: Data, nonce: Data) throws -> Data {
        let key = try getOrCreateKey()

        guard ciphertext.count > 16 else {
            throw EncryptionError.invalidData
        }

        let gcmNonce = try AES.GCM.Nonce(data: nonce)
        let tagLength = 16
        let actualCiphertext = ciphertext.dropLast(tagLength)
        let tag = ciphertext.suffix(tagLength)

        let sealedBox = try AES.GCM.SealedBox(
            nonce: gcmNonce,
            ciphertext: actualCiphertext,
            tag: tag
        )

        return try AES.GCM.open(sealedBox, using: key)
    }

    /// Checks if an encryption key exists in the Keychain
    var hasEncryptionKey: Bool {
        (try? retrieveKeyFromKeychain()) != nil
    }

    /// Deletes the encryption key from Keychain (use with caution!)
    /// This will make all previously encrypted data unrecoverable
    func deleteKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw EncryptionError.keychainStoreFailed(status)
        }
    }

    /// Exports the encryption key for backup purposes
    /// - Returns: Base64-encoded key data
    /// - Warning: Handle this data with extreme care!
    func exportKey() throws -> String {
        let key = try getOrCreateKey()
        return key.withUnsafeBytes { Data($0).base64EncodedString() }
    }

    /// Imports a previously exported encryption key
    /// - Parameter base64Key: Base64-encoded key data
    func importKey(_ base64Key: String) throws {
        guard let keyData = Data(base64Encoded: base64Key),
              keyData.count == 32 else {
            throw EncryptionError.invalidData
        }

        // Delete existing key first
        try? deleteKey()

        // Store new key
        try storeKeyInKeychain(SymmetricKey(data: keyData))
    }

    // MARK: - Key Management

    /// Gets the existing key or creates a new one
    private func getOrCreateKey() throws -> SymmetricKey {
        if let existingKey = try? retrieveKeyFromKeychain() {
            return existingKey
        }

        // Generate new 256-bit key
        let newKey = SymmetricKey(size: .bits256)
        try storeKeyInKeychain(newKey)
        return newKey
    }

    /// Stores a key in the macOS Keychain
    private func storeKeyInKeychain(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Delete any existing key first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw EncryptionError.keychainStoreFailed(status)
        }
    }

    /// Retrieves the key from the macOS Keychain
    private func retrieveKeyFromKeychain() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let keyData = result as? Data else {
            throw EncryptionError.keychainRetrieveFailed(status)
        }

        return SymmetricKey(data: keyData)
    }
}

// MARK: - Convenience Extensions

extension EncryptionService {
    /// Encrypted wrapper for JSON-encodable objects
    func encryptObject<T: Encodable>(_ object: T) throws -> (ciphertext: Data, nonce: Data) {
        let data = try JSONEncoder().encode(object)
        return try encryptData(data)
    }

    /// Decrypts and decodes a JSON object
    func decryptObject<T: Decodable>(_ type: T.Type, ciphertext: Data, nonce: Data) throws -> T {
        let data = try decryptData(ciphertext, nonce: nonce)
        return try JSONDecoder().decode(type, from: data)
    }
}
