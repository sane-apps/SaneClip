import Foundation
import SaneUI

/// Wraps the shared SaneUI keychain so a SecurityServer stall can never hang
/// the main thread at launch.
///
/// Root cause it guards: `LicenseService.checkCachedLicense()` runs
/// synchronously on the main thread, and the pinned SaneUI performs bare
/// `SecItemCopyMatching` reads there. When macOS posts a login-keychain ACL
/// prompt nobody can answer (idle console, signature changed since the item
/// was written), the main thread blocks in `mach_msg` to SecurityServer and
/// the app never finishes launching (spindump: `applicationDidFinishLaunching`
/// -> `checkCachedLicense` -> `KeychainService.string` -> `SecItemCopyMatching`).
///
/// Every operation runs on a background queue with a bounded wait. Reads and
/// writes that time out throw `timedOut` so launch can finish without treating
/// a stalled SecurityServer as "no license" (that path used to mint a fresh
/// 14-day trial for paying customers). LicenseService then applies sticky
/// unlock if one exists and does not start a new trial. A timed-out operation
/// keeps running in the background and still lands if SecurityServer eventually
/// answers.
final class NonBlockingKeychainService: KeychainServiceProtocol, Sendable {
    private let inner: KeychainServiceProtocol
    private let timeout: TimeInterval
    private let queue = DispatchQueue(
        label: "com.saneclip.nonblocking-keychain",
        qos: .userInitiated
    )

    init(wrapping inner: KeychainServiceProtocol, timeout: TimeInterval = 2.0) {
        self.inner = inner
        self.timeout = timeout
    }

    /// App-default license keychain: the same backing store SaneUI uses when
    /// no keychain is injected, but safe to call on the main thread at launch.
    static func appLicenseKeychain(timeout: TimeInterval = 2.0) -> KeychainServiceProtocol {
        NonBlockingKeychainService(
            wrapping: KeychainService(
                service: Bundle.main.bundleIdentifier ?? "com.saneapps.saneclip"
            ),
            timeout: timeout
        )
    }

    func bool(forKey key: String) throws -> Bool? {
        try read(operation: "bool(\(key))") { try self.inner.bool(forKey: key) }
    }

    func string(forKey key: String) throws -> String? {
        try read(operation: "string(\(key))") { try self.inner.string(forKey: key) }
    }

    func set(_ value: Bool, forKey key: String) throws {
        try write(operation: "setBool(\(key))") { try self.inner.set(value, forKey: key) }
    }

    func set(_ value: String, forKey key: String) throws {
        try write(operation: "setString(\(key))") { try self.inner.set(value, forKey: key) }
    }

    func delete(_ key: String) throws {
        try write(operation: "delete(\(key))") { try self.inner.delete(key) }
    }

    // MARK: - Private

    private func read<T: Sendable>(
        operation: String,
        work: @Sendable @escaping () throws -> T?
    ) throws -> T? {
        switch run(operation: operation, work: work) {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }

    private func write(operation: String, work: @Sendable @escaping () throws -> Void) throws {
        switch run(operation: operation, work: { try work(); return true }) {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }

    private func run<T: Sendable>(
        operation: String,
        work: @Sendable @escaping () throws -> T
    ) -> Result<T, Error> {
        let slot = BlockingSlot<T>()
        queue.async { slot.complete(with: Result { try work() }) }
        guard slot.wait(timeout: timeout) else {
            return .failure(NonBlockingKeychainError.timedOut(operation: operation))
        }
        return slot.result ?? .failure(NonBlockingKeychainError.timedOut(operation: operation))
    }
}

enum NonBlockingKeychainError: Error, Equatable {
    case timedOut(operation: String)
}

/// One-shot handoff between the background worker and the waiting caller.
private final class BlockingSlot<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var stored: Result<T, Error>?

    func complete(with result: Result<T, Error>) {
        lock.lock()
        stored = result
        lock.unlock()
        semaphore.signal()
    }

    func wait(timeout: TimeInterval) -> Bool {
        semaphore.wait(timeout: .now() + timeout) == .success
    }

    var result: Result<T, Error>? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}
