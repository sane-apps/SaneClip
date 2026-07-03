import AppKit

/// Single-instance guard for SaneClip.
///
/// A clipboard manager must never run as two copies: both would monitor the
/// pasteboard, double-capture every copy, and fight over the same on-disk
/// history — exactly the "multiple versions running at once" failure. macOS
/// blocks a second launch of the *same* bundle through the Dock/Finder/`open`,
/// but not a direct binary launch, a leftover copy in another folder, or a
/// login-item race, so we guard it explicitly at launch.
extension SaneClipAppDelegate {
    /// Runs before `applicationDidFinishLaunching`. If another live instance of
    /// this exact build is already running, bring it forward and quit this one
    /// before any capture or window setup happens.
    func applicationWillFinishLaunching(_: Notification) {
        guard Self.shouldTerminateAsDuplicateInstance() else { return }
        appLogger.info("Another SaneClip instance is already running — activating it and quitting this duplicate.")
        Self.activateExistingInstance()
        NSApp.terminate(nil)
    }

    /// Pure, unit-testable decision with a total-order tiebreak: this instance
    /// quits only when another instance holds a LOWER pid. Because pids are
    /// unique, exactly one instance (the lowest pid) ever survives — two copies
    /// launched at the same instant can never both quit and leave nothing
    /// running (the mutual-suicide race).
    nonisolated static func shouldTerminateAsDuplicate(selfPID: Int32, otherPIDs: [Int32]) -> Bool {
        otherPIDs.contains { $0 < selfPID }
    }

    /// True when the XCTest host is running, so the test process (a separate
    /// executable that is not the app) is never mistaken for a peer instance.
    nonisolated static func isRunningUnderTestHost(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
    }

    private static func otherRunningInstances() -> [NSRunningApplication] {
        guard let bundleID = Bundle.main.bundleIdentifier else { return [] }
        let selfPID = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != selfPID && !$0.isTerminated }
    }

    private static func shouldTerminateAsDuplicateInstance() -> Bool {
        guard !isRunningUnderTestHost() else { return false }
        return shouldTerminateAsDuplicate(
            selfPID: ProcessInfo.processInfo.processIdentifier,
            otherPIDs: otherRunningInstances().map(\.processIdentifier)
        )
    }

    private static func activateExistingInstance() {
        // Bring forward the instance that will survive — the lowest pid.
        otherRunningInstances()
            .min(by: { $0.processIdentifier < $1.processIdentifier })?
            .activate(options: [.activateAllWindows])
    }
}
