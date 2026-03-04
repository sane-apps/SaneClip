import Foundation
import SaneUI
#if !APP_STORE
    @preconcurrency import ApplicationServices
#endif

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
    #if APP_STORE
        let accessibilityStatus = "not_applicable_app_store"
    #else
        let accessibilityStatus = "\(AXIsProcessTrusted())"
    #endif

    guard let manager = ClipboardManager.shared else {
        return """
        accessibilityGranted: \(accessibilityStatus)
        clipboardManager: NOT_INITIALIZED
        """
    }

    return """
    accessibilityGranted: \(accessibilityStatus)
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
