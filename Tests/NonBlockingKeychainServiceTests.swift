import Foundation
import SaneUI
@testable import SaneClip
import Testing

/// Guards the launch-hang fix: a SecurityServer stall must never block the
/// caller — reads degrade to nil (free/trial fallback), writes throw.
@Suite("NonBlockingKeychainService")
struct NonBlockingKeychainServiceTests {
    private final class FastStub: KeychainServiceProtocol, @unchecked Sendable {
        var strings: [String: String] = ["k": "v"]
        var bools: [String: Bool] = ["b": true]
        var deleted: [String] = []

        func bool(forKey key: String) throws -> Bool? { bools[key] }
        func set(_ value: Bool, forKey key: String) throws { bools[key] = value }
        func string(forKey key: String) throws -> String? { strings[key] }
        func set(_ value: String, forKey key: String) throws { strings[key] = value }
        func delete(_ key: String) throws {
            bools.removeValue(forKey: key)
            strings.removeValue(forKey: key)
            deleted.append(key)
        }
    }

    private final class HangingStub: KeychainServiceProtocol, @unchecked Sendable {
        func bool(forKey key: String) throws -> Bool? {
            Thread.sleep(forTimeInterval: 5)
            return true
        }

        func set(_ value: Bool, forKey key: String) throws {
            Thread.sleep(forTimeInterval: 5)
        }

        func string(forKey key: String) throws -> String? {
            Thread.sleep(forTimeInterval: 5)
            return "late"
        }

        func set(_ value: String, forKey key: String) throws {
            Thread.sleep(forTimeInterval: 5)
        }

        func delete(_ key: String) throws {
            Thread.sleep(forTimeInterval: 5)
        }
    }

    private struct Boom: Error {}
    private final class ThrowingStub: KeychainServiceProtocol, @unchecked Sendable {
        func bool(forKey key: String) throws -> Bool? { throw Boom() }
        func set(_ value: Bool, forKey key: String) throws { throw Boom() }
        func string(forKey key: String) throws -> String? { throw Boom() }
        func set(_ value: String, forKey key: String) throws { throw Boom() }
        func delete(_ key: String) throws { throw Boom() }
    }

    @Test("passes reads and writes through when keychain answers")
    func passthrough() throws {
        let inner = FastStub()
        let keychain = NonBlockingKeychainService(wrapping: inner, timeout: 2)
        #expect(try keychain.string(forKey: "k") == "v")
        #expect(try keychain.bool(forKey: "b") == true)
        #expect(try keychain.string(forKey: "missing") == nil)
        try keychain.set("n", forKey: "k2")
        #expect(try keychain.string(forKey: "k2") == "n")
        try keychain.delete("k2")
        #expect(try keychain.string(forKey: "k2") == nil)
    }

    @Test("stalled read returns nil inside the bound")
    func stalledReadDegradesToNil() throws {
        let keychain = NonBlockingKeychainService(wrapping: HangingStub(), timeout: 0.1)
        let start = Date()
        #expect(try keychain.string(forKey: "k") == nil)
        #expect(try keychain.bool(forKey: "b") == nil)
        #expect(Date().timeIntervalSince(start) < 2)
    }

    @Test("stalled write throws timedOut instead of hanging")
    func stalledWriteThrows() {
        let keychain = NonBlockingKeychainService(wrapping: HangingStub(), timeout: 0.1)
        #expect(throws: NonBlockingKeychainError.timedOut(operation: "setString(k)")) {
            try keychain.set("v", forKey: "k")
        }
        #expect(throws: NonBlockingKeychainError.timedOut(operation: "delete(k)")) {
            try keychain.delete("k")
        }
    }

    @Test("inner errors propagate instead of degrading to nil")
    func innerErrorsPropagate() {
        let keychain = NonBlockingKeychainService(wrapping: ThrowingStub(), timeout: 2)
        #expect(throws: Boom.self) { try keychain.string(forKey: "k") }
    }
}
