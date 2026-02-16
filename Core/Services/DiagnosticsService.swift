import AppKit
@preconcurrency import ApplicationServices
import Foundation
import OSLog

// MARK: - DiagnosticReport

struct DiagnosticReport: Sendable {
    let appVersion: String
    let buildNumber: String
    let macOSVersion: String
    let hardwareModel: String
    let recentLogs: [LogEntry]
    let settingsSummary: String
    let collectedAt: Date

    struct LogEntry: Sendable {
        let timestamp: Date
        let level: String
        let message: String
    }

    func toMarkdown(userDescription: String) -> String {
        var md = """
        ## Issue Description
        \(userDescription)

        ---

        ## Environment
        | Property | Value |
        |----------|-------|
        | App Version | \(appVersion) (\(buildNumber)) |
        | macOS | \(macOSVersion) |
        | Hardware | \(hardwareModel) |
        | Accessibility | \(AXIsProcessTrusted() ? "Granted" : "NOT GRANTED") |
        | Collected | \(ISO8601DateFormatter().string(from: collectedAt)) |

        """

        if !recentLogs.isEmpty {
            md += """

            ## Recent Logs (last 5 minutes)
            ```
            \(formattedLogs)
            ```

            """
        }

        md += """

        ## Settings Summary
        ```
        \(settingsSummary)
        ```

        ---
        *Submitted via SaneClip's in-app feedback*
        """

        return md
    }

    private var formattedLogs: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"

        return recentLogs.prefix(50).map { entry in
            "[\(formatter.string(from: entry.timestamp))] [\(entry.level)] \(entry.message)"
        }.joined(separator: "\n")
    }
}

// MARK: - DiagnosticsService

final class DiagnosticsService: @unchecked Sendable {
    static let shared = DiagnosticsService()

    private let subsystem = "com.saneclip.app"

    func collectDiagnostics() async -> DiagnosticReport {
        async let logs = collectRecentLogs()
        async let settings = collectSettingsSummary()

        return await DiagnosticReport(
            appVersion: appVersion,
            buildNumber: buildNumber,
            macOSVersion: macOSVersion,
            hardwareModel: hardwareModel,
            recentLogs: logs,
            settingsSummary: settings,
            collectedAt: Date()
        )
    }

    // MARK: - App Info

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    // MARK: - System Info

    private var macOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private var hardwareModel: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let modelString = String(bytes: model.prefix(while: { $0 != 0 }).map(UInt8.init), encoding: .utf8) ?? "Unknown"

        #if arch(arm64)
            return "\(modelString) (Apple Silicon)"
        #else
            return "\(modelString) (Intel)"
        #endif
    }

    // MARK: - Log Collection

    private func collectRecentLogs() async -> [DiagnosticReport.LogEntry] {
        guard #available(macOS 15.0, *) else {
            return [
                DiagnosticReport.LogEntry(
                    timestamp: Date(),
                    level: "INFO",
                    message: "Log collection requires macOS 15+. Current OS: \(macOSVersion). Paste logs manually: log show --predicate 'subsystem == \"com.saneclip.app\"' --last 5m --style compact"
                )
            ]
        }

        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let fiveMinutesAgo = Date().addingTimeInterval(-5 * 60)
            let position = store.position(date: fiveMinutesAgo)

            let predicate = NSPredicate(format: "subsystem == %@", subsystem)
            let entries = try store.getEntries(at: position, matching: predicate)

            return entries.compactMap { entry -> DiagnosticReport.LogEntry? in
                guard let logEntry = entry as? OSLogEntryLog else { return nil }

                let level = switch logEntry.level {
                case .debug: "DEBUG"
                case .info: "INFO"
                case .notice: "NOTICE"
                case .error: "ERROR"
                case .fault: "FAULT"
                default: "LOG"
                }

                return DiagnosticReport.LogEntry(
                    timestamp: logEntry.date,
                    level: level,
                    message: sanitize(logEntry.composedMessage)
                )
            }
        } catch {
            return [
                DiagnosticReport.LogEntry(
                    timestamp: Date(),
                    level: "ERROR",
                    message: "Failed to collect logs: \(error.localizedDescription)"
                ),
                DiagnosticReport.LogEntry(
                    timestamp: Date(),
                    level: "INFO",
                    message: "Tip: paste logs manually by running in Terminal: log show --predicate 'subsystem == \"com.saneclip.app\"' --last 5m --style compact"
                )
            ]
        }
    }

    // MARK: - Settings Summary

    private func collectSettingsSummary() async -> String {
        await MainActor.run {
            let settings = SettingsModel.shared

            guard let manager = ClipboardManager.shared else {
                return """
                accessibilityGranted: \(AXIsProcessTrusted())
                clipboardManager: NOT_INITIALIZED
                """
            }

            return """
            accessibilityGranted: \(AXIsProcessTrusted())
            historyCount: \(manager.history.count)
            pinnedCount: \(manager.pinnedItems.count)
            pasteStackCount: \(manager.pasteStack.count)

            settings:
              maxHistorySize: \(settings.maxHistorySize)
              defaultPasteMode: \(settings.defaultPasteMode.rawValue)
              pasteSound: \(settings.pasteSound.rawValue)
              protectPasswords: \(settings.protectPasswords)
              encryptHistory: \(settings.encryptHistory)
              autoExpireHours: \(settings.autoExpireHours)
              pasteStackReversed: \(settings.pasteStackReversed)
              excludedApps: \(settings.excludedApps.count)
              stripTrackingParams: \(ClipboardRulesManager.shared.stripTrackingParams)
              autoTrimWhitespace: \(ClipboardRulesManager.shared.autoTrimWhitespace)
              snippets: \(SnippetManager.shared.snippets.count)
            """
        }
    }

    // MARK: - Privacy

    private func sanitize(_ message: String) -> String {
        var sanitized = message

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        sanitized = sanitized.replacingOccurrences(of: homeDir, with: "~")

        let patterns = [
            "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
            "\\b[A-Za-z0-9]{32,}\\b"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                sanitized = regex.stringByReplacingMatches(
                    in: sanitized,
                    range: NSRange(sanitized.startIndex..., in: sanitized),
                    withTemplate: "[REDACTED]"
                )
            }
        }

        return sanitized
    }
}

// MARK: - GitHub Issue URL Generation

extension DiagnosticReport {
    func gitHubIssueURL(title: String, userDescription: String) -> URL? {
        let body = toMarkdown(userDescription: userDescription)

        var components = URLComponents(string: "https://github.com/sane-apps/SaneClip/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "body", value: body)
        ]

        return components?.url
    }
}
