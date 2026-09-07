import AppKit
import SaneUI
import SwiftUI
import Testing

@Suite("Expired license gate", .serialized)
@MainActor
struct LicenseGateWindowTests {
    private struct EmptyKeychain: KeychainServiceProtocol {
        func bool(forKey key: String) throws -> Bool? { nil }
        func string(forKey key: String) throws -> String? { nil }
        func set(_ value: Bool, forKey key: String) throws {}
        func set(_ value: String, forKey key: String) throws {}
        func delete(_ key: String) throws {}
    }

    @Test("Expired gate closes and reopens without granting access")
    func expiredGateCanCloseWithoutUnlocking() async throws {
        let suite = "tests.saneclip.gate.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Date().addingTimeInterval(-15 * 86400).timeIntervalSince1970,
                     forKey: "test.trial.started_at")
        let license = LicenseService(
            appName: "SaneClip",
            checkoutURL: try #require(URL(string: "https://saneclip.com")),
            keychain: EmptyKeychain(),
            proTrial: .init(storageKeyPrefix: "test.trial"),
            userDefaults: defaults
        )
        license.checkCachedLicense()
        try #require(license.hasExpiredProTrial)
        let window = NSWindow(contentViewController: NSHostingController(
            rootView: LicenseGateView(licenseService: license, appIcon: "list.clipboard.fill")
        ))
        window.isReleasedWhenClosed = false
        window.title = "SaneClip Trial Ended — Regression"
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }

        // Let SwiftUI appearance and its queued AppKit changes run first.
        try await Task.sleep(for: .milliseconds(300))
        try #require(window.styleMask.contains(.closable))
        let close = try #require(window.standardWindowButton(.closeButton))
        try #require(close.isEnabled)
        close.performClick(nil)
        try await Task.sleep(for: .milliseconds(100))
        #expect(!window.isVisible)
        #expect(!license.isLicensed)
        #expect(!license.isPro)
        #expect(license.hasExpiredProTrial)

        window.makeKeyAndOrderFront(nil)
        try await Task.sleep(for: .milliseconds(100))
        #expect(window.isVisible)
        window.performClose(nil)
        try await Task.sleep(for: .milliseconds(100))
        #expect(!window.isVisible)
        #expect(license.hasExpiredProTrial)
    }
}
