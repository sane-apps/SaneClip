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
    private enum ExistingInstanceActivationResult: Equatable {
        case noSurvivor
        case activated
        case survivorStillRunning
    }

    /// Runs before `applicationDidFinishLaunching`. If another live instance of
    /// any SaneClip channel is already running, bring it forward and quit this one
    /// before any capture or window setup happens.
    func applicationWillFinishLaunching(_: Notification) {
        _ = terminateDuplicateIfNeeded()
    }

    /// Repeat arbitration once Launch Services has fully registered this process.
    /// This closes the simultaneous-launch window where neither app was visible
    /// during `applicationWillFinishLaunching`.
    @discardableResult
    func terminateDuplicateIfNeeded() -> Bool {
        guard Self.shouldTerminateAsDuplicateInstance() else { return false }
        let activationResult = Self.activateExistingInstance()
        guard activationResult != .noSurvivor else {
            appLogger.info("An older SaneClip instance disappeared before activation — continuing this launch.")
            return false
        }
        if activationResult == .activated {
            appLogger.info("Another SaneClip instance is already running — activated it and quitting this duplicate.")
        } else {
            appLogger.info("Another SaneClip instance is still running but could not be activated — quitting this duplicate.")
        }
        NSApp.terminate(nil)
        return true
    }

    /// Pure, unit-testable decision: an older SaneClip instance wins. PID is
    /// only the deterministic tiebreak for equal or unavailable launch dates,
    /// so PID wrap cannot let a newly launched duplicate replace the existing app.
    nonisolated static func shouldTerminateAsDuplicate(
        selfPID: Int32,
        selfLaunchDate: Date?,
        otherInstances: [(pid: Int32, launchDate: Date?)]
    ) -> Bool {
        otherInstances.contains { other in
            switch (selfLaunchDate, other.launchDate) {
            case let (selfDate?, otherDate?):
                otherDate < selfDate || (otherDate == selfDate && other.pid < selfPID)
            case (nil, .some):
                true
            case (.some, nil):
                false
            case (nil, nil):
                other.pid < selfPID
            }
        }
    }

    /// True when the XCTest host is running, so the test process (a separate
    /// executable that is not the app) is never mistaken for a peer instance.
    nonisolated static func isRunningUnderTestHost(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
    }

    /// Direct, Debug, App Store, and Setapp builds are separate bundle identities,
    /// but they are still one clipboard manager and must never monitor together.
    nonisolated static func isSaneClipBundleIdentifier(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return bundleIdentifier == "com.saneclip.app"
            || bundleIdentifier == "com.saneclip.dev"
            || bundleIdentifier == "com.saneclip.app-setapp"
    }

    private static func otherRunningInstances() -> [NSRunningApplication] {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications.filter {
            $0.processIdentifier != selfPID
                && !$0.isTerminated
                && isSaneClipBundleIdentifier($0.bundleIdentifier)
        }
    }

    private static func shouldTerminateAsDuplicateInstance() -> Bool {
        guard !isRunningUnderTestHost() else { return false }
        return shouldTerminateAsDuplicate(
            selfPID: ProcessInfo.processInfo.processIdentifier,
            selfLaunchDate: NSRunningApplication.current.launchDate,
            otherInstances: otherRunningInstances().map {
                (pid: $0.processIdentifier, launchDate: $0.launchDate)
            }
        )
    }

    private static func activateExistingInstance() -> ExistingInstanceActivationResult {
        // Bring forward the oldest instance; PID is the deterministic fallback.
        guard let survivor = otherRunningInstances().min(by: { lhsApp, rhsApp in
                switch (lhsApp.launchDate, rhsApp.launchDate) {
                case let (lhs?, rhs?):
                    lhs == rhs ? lhsApp.processIdentifier < rhsApp.processIdentifier : lhs < rhs
                case (.some, nil):
                    true
                case (nil, .some):
                    false
                case (nil, nil):
                    lhsApp.processIdentifier < rhsApp.processIdentifier
                }
            })
        else { return .noSurvivor }

        if survivor.activate(options: [.activateAllWindows]) {
            return .activated
        }

        let survivorAfterAttempt = NSRunningApplication(processIdentifier: survivor.processIdentifier)
        return survivorAfterAttempt?.isTerminated == false ? .survivorStillRunning : .noSurvivor
    }
}
