import AppKit
import Combine
import os.log
import SaneUI

#if !APP_STORE && !SETAPP
import Sparkle

private let updateLogger = Logger(subsystem: "com.saneclip.app", category: "Update")

enum SparkleErrorCode: Int32 {
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
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        configureUpdatePolicy()
        updaterController?.updater.checkForUpdatesInBackground()
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
        updateLogger.error(
            "Sparkle update cycle failed: domain=\(error.domain, privacy: .public) code=\(error.code) description=\(error.localizedDescription, privacy: .public)"
        )
        if Self.shouldOfferManualDownloadFallback(for: error, updateCheck: updateCheck) {
            updateLogger.error("Sparkle install diagnostics: \(Self.sparkleInstallationDiagnostics(), privacy: .public)")
        }

        guard Self.shouldOfferManualDownloadFallback(for: error, updateCheck: updateCheck) else { return }
        presentManualDownloadFallback()
    }

    private func presentManualDownloadFallback() {
        guard !isPresentingManualFallback else { return }
        guard let url = URL(string: Self.manualDownloadURL) else { return }

        isPresentingManualFallback = true
        defer { isPresentingManualFallback = false }

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Update couldn’t finish automatically"
        alert.informativeText = "SaneClip couldn’t launch the installer on this Mac. Open the download page and install the latest version manually?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Download Page")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(url)
        }
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
        case .runningFromDiskImage?,
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
