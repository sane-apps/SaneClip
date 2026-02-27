@preconcurrency import ApplicationServices
import Foundation
import SaneUI

// MARK: - SaneClip Diagnostics

/// SaneClip's diagnostics service — delegates generic collection (logs, system info,
/// markdown, sanitization) to SaneDiagnosticsService and provides SaneClip-specific
/// settings and clipboard state via the settingsCollector closure.
extension SaneDiagnosticsService {
    static let shared = SaneDiagnosticsService(
        appName: "SaneClip",
        subsystem: "com.saneclip.app",
        githubRepo: "SaneClip",
        settingsCollector: { await collectSaneClipSettings() }
    )
}

// MARK: - SaneClip-Specific Settings Collection

@MainActor
private func collectSaneClipSettings() -> String {
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
