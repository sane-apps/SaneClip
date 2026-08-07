import AppKit
import Combine
import os.log
import SaneUI

#if !APP_STORE && !SETAPP
    import Sparkle

    private let updateLogger = Logger(subsystem: "com.saneclip.app", category: "Update")

    enum SparkleErrorCode: Int32 {
        case appcastParse = 1000
        case noUpdate = 1001
        case runningFromDiskImage = 1003
        case temporaryDirectory = 2000
        case download = 2001
        case unarchiving = 3000
        case validation = 3002
        case missingInstallerTool = 4003
        case relaunch = 4004
        case installation = 4005
        case installationCanceled = 4007
        case installationAuthorizeLater = 4008
        case agentInvalidation = 4010
        case installationWriteNoPermission = 4012
    }

    enum SparkleCacheMaintenance {
        static let sparkleCacheFolder = "org.sparkle-project.Sparkle"
        static let staleCacheFolders = ["Launcher", "Installation", "PersistentDownloads"]

        static func sparkleCacheRoot(
            bundleIdentifier: String,
            homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
        ) -> URL {
            homeDirectoryURL
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Caches", isDirectory: true)
                .appendingPathComponent(bundleIdentifier, isDirectory: true)
                .appendingPathComponent(sparkleCacheFolder, isDirectory: true)
        }

        static func staleArtifactURLs(
            bundleIdentifier: String,
            homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
        ) -> [URL] {
            let root = sparkleCacheRoot(bundleIdentifier: bundleIdentifier, homeDirectoryURL: homeDirectoryURL)
            return staleCacheFolders.map { root.appendingPathComponent($0, isDirectory: true) }
        }

        @discardableResult
        static func clearStaleArtifacts(
            bundleIdentifier: String,
            fileManager: FileManager = .default,
            homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
        ) -> [String] {
            staleArtifactURLs(bundleIdentifier: bundleIdentifier, homeDirectoryURL: homeDirectoryURL).compactMap { url in
                guard fileManager.fileExists(atPath: url.path) else { return nil }

                do {
                    try fileManager.removeItem(at: url)
                    return url.lastPathComponent
                } catch {
                    return "\(url.lastPathComponent):\(error.localizedDescription)"
                }
            }
        }

        static func diagnostics(
            bundleURL: URL = Bundle.main.bundleURL,
            bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "unknown",
            fileManager: FileManager = .default,
            homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
        ) -> String {
            let bundlePath = bundleURL.path
            let writable = fileManager.isWritableFile(atPath: bundlePath)
            let attributes = (try? fileManager.attributesOfItem(atPath: bundlePath)) ?? [:]
            let owner = attributes[.ownerAccountName] as? String ?? "unknown"
            let group = attributes[.groupOwnerAccountName] as? String ?? "unknown"
            let permissions = attributes[.posixPermissions] as? NSNumber
            let permissionsString = permissions.map { String($0.intValue, radix: 8) } ?? "unknown"
            let staleFolders = staleArtifactURLs(bundleIdentifier: bundleIdentifier, homeDirectoryURL: homeDirectoryURL)
                .filter { fileManager.fileExists(atPath: $0.path) }
                .map(\.lastPathComponent)
                .joined(separator: ",")
            let presentFolders = staleFolders.isEmpty ? "none" : staleFolders

            return "bundlePath=\(bundlePath) writable=\(writable) owner=\(owner):\(group) mode=\(permissionsString) sparkleCaches=\(presentFolders)"
        }

        /// True for Sparkle's cached Updater.app helpers under our app's Caches folder.
        /// These can linger after a routine "up to date" check and waste RAM until quit.
        static func isOrphanedSparkleUpdaterApp(
            bundleURL: URL,
            bundleIdentifier: String
        ) -> Bool {
            let path = bundleURL.path
            guard path.contains("/\(bundleIdentifier)/") else { return false }
            guard path.contains("/\(sparkleCacheFolder)/Launcher/") else { return false }
            return path.hasSuffix("/Updater.app") || path.contains("/Updater.app/")
        }
    }

    @MainActor
    class UpdateService: NSObject, ObservableObject, SPUUpdaterDelegate {
        static let shared = UpdateService()

        nonisolated static let manualDownloadURL = "https://saneclip.com/download"
        nonisolated static let testFeedOverrideKey = "SANECLIP_TEST_FEED_URL"
        nonisolated static let autoCheckOnLaunchKey = "SANECLIP_AUTO_CHECK_FOR_UPDATES"

        nonisolated static func shouldInitialize(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
            environment["XCTestConfigurationFilePath"] == nil &&
                environment["XCTestSessionIdentifier"] == nil
        }

        nonisolated static func testFeedOverride(environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
            guard let value = environment[testFeedOverrideKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty
            else {
                return nil
            }

            return value
        }

        nonisolated static func shouldAutoCheckOnLaunch(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
            environment[autoCheckOnLaunchKey] == "1"
        }

        private var updaterController: SPUStandardUpdaterController?
        private var isPresentingManualFallback = false

        override init() {
            super.init()
            // Clear leftover Launcher/Installation caches before Sparkle starts so a
            // previous interrupted update cannot leave Updater.app helpers parked.
            let removedCaches = Self.clearStaleSparkleArtifacts()
            if removedCaches.isEmpty {
                updateLogger.info("No stale Sparkle cache artifacts found at launch")
            } else {
                updateLogger.info(
                    "Cleared stale Sparkle cache artifacts at launch: \(removedCaches.joined(separator: ","), privacy: .public)"
                )
            }
            let terminated = Self.terminateOrphanedSparkleHelpers()
            if terminated > 0 {
                updateLogger.info("Terminated \(terminated) orphaned Sparkle updater helper(s) at launch")
            }

            updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: self,
                userDriverDelegate: nil
            )
            configureUpdatePolicy()
            // startingUpdater already schedules automatic checks; avoid a second
            // immediate background check that can leave Updater.app lingering.
            updateLogger.info("Sparkle updater initialized")
        }

        func checkForUpdates() {
            updateLogger.info("User triggered check for updates")
            let removedCaches = Self.clearStaleSparkleArtifacts()
            if removedCaches.isEmpty {
                updateLogger.info("No stale Sparkle cache artifacts found before manual update check")
            } else {
                updateLogger.info("Cleared stale Sparkle cache artifacts before manual update check: \(removedCaches.joined(separator: ","), privacy: .public)")
            }
            _ = Self.terminateOrphanedSparkleHelpers()
            updaterController?.checkForUpdates(nil)
        }

        private func configureUpdatePolicy() {
            guard let updater = updaterController?.updater else { return }
            updater.automaticallyDownloadsUpdates = true
            updater.updateCheckInterval = SaneSparkleCheckFrequency.normalizedInterval(from: updater.updateCheckInterval)
        }

        nonisolated func updater(_: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
            guard let nsError = error as NSError? else { return }
            Task { @MainActor in
                self.handleFinishedUpdateCycle(updateCheck: updateCheck, error: nsError)
            }
        }

        private func handleFinishedUpdateCycle(updateCheck: SPUUpdateCheck, error: NSError) {
            // "You're up to date" (noUpdate / 1001) is the normal, expected result
            // of a routine check — not a failure. Logging it at error level
            // pollutes the customer's diagnostics with fake errors on every check.
            if Self.isRoutineNoUpdate(error) {
                updateLogger.info("Sparkle: no update available (up to date)")
                Self.cleanupIdleSparkleHelpers(reason: "no update available")
                return
            }

            updateLogger.error(
                "Sparkle update cycle failed: domain=\(error.domain, privacy: .public) code=\(error.code) description=\(error.localizedDescription, privacy: .public)"
            )
            if Self.shouldOfferManualDownloadFallback(for: error, updateCheck: updateCheck) {
                updateLogger.error("Sparkle install diagnostics: \(Self.sparkleInstallationDiagnostics(), privacy: .public)")
            }

            guard Self.shouldOfferManualDownloadFallback(for: error, updateCheck: updateCheck) else { return }
            presentManualDownloadFallback()
        }

        /// True for Sparkle's "you're up to date" result — a normal check outcome
        /// Sparkle reports as an error, which must never be logged as a failure.
        nonisolated static func isRoutineNoUpdate(_ error: NSError) -> Bool {
            error.domain == SUSparkleErrorDomain
                && SparkleErrorCode(rawValue: Int32(error.code)) == .noUpdate
        }

        nonisolated static func cleanupIdleSparkleHelpers(reason: String) {
            let terminated = terminateOrphanedSparkleHelpers()
            let removedCaches = clearStaleSparkleArtifacts()
            if terminated > 0 || !removedCaches.isEmpty {
                updateLogger.info(
                    "Sparkle idle cleanup (\(reason, privacy: .public)): terminated=\(terminated) cleared=\(removedCaches.joined(separator: ","), privacy: .public)"
                )
            }
            // Updater.app helpers can force a Dock tile; re-enforce accessory/regular
            // after they quit so tiles do not accumulate across automatic checks.
            Task { @MainActor in
                SaneActivationPolicy.restorePolicy(showDockIcon: SettingsModel.shared.showInDock)
            }
        }

        /// Quit cached Sparkle Updater.app helpers for this bundle after idle cycles.
        @discardableResult
        nonisolated static func terminateOrphanedSparkleHelpers(
            bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.saneclip.app",
            runningApplications: [NSRunningApplication] = NSWorkspace.shared.runningApplications
        ) -> Int {
            var terminated = 0
            for app in runningApplications {
                guard let bundleURL = app.bundleURL else { continue }
                guard SparkleCacheMaintenance.isOrphanedSparkleUpdaterApp(
                    bundleURL: bundleURL,
                    bundleIdentifier: bundleIdentifier
                ) else { continue }
                if app.terminate() {
                    terminated += 1
                }
            }
            return terminated
        }

        private func presentManualDownloadFallback() {
            guard !isPresentingManualFallback else { return }
            guard let url = URL(string: Self.manualDownloadURL) else { return }

            isPresentingManualFallback = true
            defer { isPresentingManualFallback = false }

            NSApp.activate(ignoringOtherApps: true)

            let alert = NSAlert()
            alert.messageText = "Update couldn’t finish automatically"
            alert.informativeText = "SaneClip couldn’t complete the automatic update on this Mac. Open the download page and install the latest version manually?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Download Page")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(url)
            }
            SaneActivationPolicy.restorePolicy(showDockIcon: SettingsModel.shared.showInDock)
        }

        nonisolated static func shouldOfferManualDownloadFallback(for error: NSError, updateCheck: SPUUpdateCheck) -> Bool {
            guard updateCheck == .updates else { return false }
            guard error.domain == SUSparkleErrorDomain else { return false }

            switch SparkleErrorCode(rawValue: Int32(error.code)) {
            case .none,
                 .noUpdate?,
                 .installationCanceled?,
                 .installationAuthorizeLater?:
                return false
            case .appcastParse?,
                 .runningFromDiskImage?,
                 .temporaryDirectory?,
                 .download?,
                 .unarchiving?,
                 .validation?,
                 .missingInstallerTool?,
                 .relaunch?,
                 .installation?,
                 .agentInvalidation?,
                 .installationWriteNoPermission?:
                return true
            }
        }

        nonisolated static func clearStaleSparkleArtifacts(
            bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.saneclip.app",
            fileManager: FileManager = .default,
            homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
        ) -> [String] {
            SparkleCacheMaintenance.clearStaleArtifacts(
                bundleIdentifier: bundleIdentifier,
                fileManager: fileManager,
                homeDirectoryURL: homeDirectoryURL
            )
        }

        nonisolated static func sparkleInstallationDiagnostics(
            bundleURL: URL = Bundle.main.bundleURL,
            bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.saneclip.app",
            fileManager: FileManager = .default,
            homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
        ) -> String {
            SparkleCacheMaintenance.diagnostics(
                bundleURL: bundleURL,
                bundleIdentifier: bundleIdentifier,
                fileManager: fileManager,
                homeDirectoryURL: homeDirectoryURL
            )
        }

        var automaticallyChecksForUpdates: Bool {
            get { updaterController?.updater.automaticallyChecksForUpdates ?? true }
            set { updaterController?.updater.automaticallyChecksForUpdates = newValue }
        }

        var updateCheckFrequency: SaneSparkleCheckFrequency {
            get {
                let interval = updaterController?.updater.updateCheckInterval ?? SaneSparkleCheckFrequency.daily.interval
                return SaneSparkleCheckFrequency.resolve(updateCheckInterval: interval)
            }
            set {
                updaterController?.updater.updateCheckInterval = newValue.interval
            }
        }
    }
#endif
