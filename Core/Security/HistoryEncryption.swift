import CryptoKit
import Foundation

/// AES-GCM encryption for clipboard history at rest.
/// Key is auto-generated on first use and stored in Keychain.
enum HistoryEncryption {
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

    /// Distinguishes AES-GCM blobs from plaintext JSON payloads.
    ///
    /// Fast path: the AES-GCM combined format starts with a 12-byte random
    /// nonce, so a first byte outside the JSON start set means encrypted.
    /// BUT the nonce's first byte is uniform random — ~2.3% (6/256) of real
    /// ciphertexts start with a JSON-looking byte, so the old first-byte-only
    /// check misjudged ~1 in 43 encrypted records as plaintext (and made the
    /// sync round-trip test flaky). For that ambiguous slice we confirm by
    /// attempting a full JSON parse: random ciphertext passing a complete
    /// JSON parse is genuinely negligible, and plaintext records are always
    /// JSONEncoder output, which parses.
    static func isEncrypted(_ data: Data) -> Bool {
        guard let firstByte = data.first else { return false }
        // JSON arrays start with 0x5B `[`, objects with 0x7B `{`
        // Whitespace before JSON: 0x20 (space), 0x09 (tab), 0x0A (LF), 0x0D (CR)
        let jsonStartBytes: Set<UInt8> = [0x5B, 0x7B, 0x20, 0x09, 0x0A, 0x0D]
        guard jsonStartBytes.contains(firstByte) else { return true }

        // Ambiguous first byte: encrypted only if it is NOT actually JSON.
        return (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) == nil
    }

    // MARK: - Key Management

    private static func getOrCreateKey() throws -> SymmetricKey {
        switch KeychainHelper.loadResult(account: KeychainHelper.historyEncryptionKeyAccount) {
        case let .found(keyData):
            return SymmetricKey(data: keyData)
        case .missing:
            break
        case .interactionNotAllowed:
            throw EncryptionError.keyAccessRequiresUserApproval
        case .failed:
            throw EncryptionError.keyStoreFailed
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
        case keyAccessRequiresUserApproval
        case keyStoreFailed

        var errorDescription: String? {
            switch self {
            case .sealFailed: "Failed to encrypt data"
            case .keyAccessRequiresUserApproval: "SaneClip needs permission to access the existing history encryption key"
            case .keyStoreFailed: "Failed to store encryption key in Keychain"
            }
        }
    }
}
