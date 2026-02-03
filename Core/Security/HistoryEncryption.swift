import CryptoKit
import Foundation

/// AES-GCM encryption for clipboard history at rest.
/// Key is auto-generated on first use and stored in Keychain.
struct HistoryEncryption: Sendable {

    /// Encrypts plaintext data using AES-GCM.
    /// Returns combined nonce + ciphertext + tag.
    static func encrypt(_ plaintext: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.sealFailed
        }
        return combined
    }

    /// Decrypts AES-GCM encrypted data (nonce + ciphertext + tag).
    static func decrypt(_ ciphertext: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: ciphertext)
        return try AES.GCM.open(sealedBox, using: key)
    }

    /// Heuristic: encrypted data never starts with `[` or `{` (JSON markers).
    /// AES-GCM nonce is 12 random bytes, so the probability of a false positive is negligible.
    static func isEncrypted(_ data: Data) -> Bool {
        guard let firstByte = data.first else { return false }
        // JSON arrays start with 0x5B `[`, objects with 0x7B `{`
        // Whitespace before JSON: 0x20 (space), 0x09 (tab), 0x0A (LF), 0x0D (CR)
        let jsonStartBytes: Set<UInt8> = [0x5B, 0x7B, 0x20, 0x09, 0x0A, 0x0D]
        return !jsonStartBytes.contains(firstByte)
    }

    // MARK: - Key Management

    private static func getOrCreateKey() throws -> SymmetricKey {
        if let keyData = KeychainHelper.load(account: KeychainHelper.historyEncryptionKeyAccount) {
            return SymmetricKey(data: keyData)
        }

        // Generate new 256-bit key
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }

        guard KeychainHelper.save(data: keyData, account: KeychainHelper.historyEncryptionKeyAccount) else {
            throw EncryptionError.keyStoreFailed
        }

        return key
    }

    // MARK: - Errors

    enum EncryptionError: Error, LocalizedError {
        case sealFailed
        case keyStoreFailed

        var errorDescription: String? {
            switch self {
            case .sealFailed: return "Failed to encrypt data"
            case .keyStoreFailed: return "Failed to store encryption key in Keychain"
            }
        }
    }
}
