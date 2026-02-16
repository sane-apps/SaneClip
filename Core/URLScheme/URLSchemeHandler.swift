import AppKit
import Foundation
import LocalAuthentication

/// Notification names for URL scheme actions
extension Notification.Name {
    static let openSearchWithQuery = Notification.Name("SaneClipOpenSearchWithQuery")
    static let triggerExport = Notification.Name("SaneClipTriggerExport")
    static let showHistory = Notification.Name("SaneClipShowHistory")
    static let pasteAtIndex = Notification.Name("SaneClipPasteAtIndex")
    static let dismissForPaste = Notification.Name("SaneClipDismissForPaste")
}

/// Parsed URL scheme command for testability
enum URLSchemeCommand: Equatable {
    case paste(index: Int)
    case search(query: String)
    case export
    case history
    case clear
    case snippet(name: String, values: [String: String])
    case copy(text: String)

    /// Whether this command modifies clipboard or triggers paste (destructive)
    var requiresConfirmation: Bool {
        switch self {
        case .copy, .paste, .snippet, .clear:
            true
        case .search, .export, .history:
            false
        }
    }
}

/// Handles saneclip:// URL scheme commands
///
/// Supported URLs:
/// - saneclip://paste?index=N - Paste item at index N
/// - saneclip://search?q=QUERY - Open search with query
/// - saneclip://export - Trigger history export
/// - saneclip://history - Show history window
/// - saneclip://clear - Clear history (with confirmation)
/// - saneclip://snippet?name=NAME - Paste snippet by name
/// - saneclip://copy?text=TEXT - Copy text to clipboard
@MainActor
final class URLSchemeHandler {
    /// Shared singleton instance
    static let shared = URLSchemeHandler()

    private init() {}

    // MARK: - Command Parsing (Pure, Testable)

    /// Parses a URL into a typed command. Returns nil for invalid URLs.
    /// Nonisolated because this is pure logic with no side effects.
    nonisolated static func parseCommand(_ url: URL) -> URLSchemeCommand? {
        guard url.scheme == "saneclip", let host = url.host else { return nil }

        switch host.lowercased() {
        case "paste":
            guard let indexString = url.queryValue(for: "index"),
                  let index = Int(indexString), index >= 0 else { return nil }
            return .paste(index: index)

        case "search":
            guard let query = url.queryValue(for: "q"), !query.isEmpty else { return nil }
            return .search(query: query)

        case "export":
            return .export

        case "history":
            return .history

        case "clear":
            return .clear

        case "snippet":
            guard let name = url.queryValue(for: "name"), !name.isEmpty else { return nil }
            // Collect placeholder values from query params
            var values: [String: String] = [:]
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems {
                for item in queryItems where item.name != "name" {
                    if let value = item.value {
                        values[item.name] = value
                    }
                }
            }
            return .snippet(name: name, values: values)

        case "copy":
            guard let text = url.queryValue(for: "text"), !text.isEmpty else { return nil }
            return .copy(text: text)

        default:
            return nil
        }
    }

    // MARK: - Confirmation Dialog

    /// Shows a confirmation dialog for external URL scheme requests.
    /// Returns true if the user confirmed.
    private func showConfirmation(title: String, message: String, confirmTitle: String = "Allow") -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    // MARK: - Handle URL

    /// Handles an incoming URL scheme request
    /// - Parameter url: The URL to handle
    /// - Returns: True if the URL was handled successfully
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard let command = Self.parseCommand(url) else {
            print("URLSchemeHandler: Invalid or unrecognized URL: \(url)")
            return false
        }

        // Destructive commands require Touch ID if enabled
        if command.requiresConfirmation, SettingsModel.shared.requireTouchID {
            guard authenticateSync() else {
                print("URLSchemeHandler: Touch ID authentication failed")
                return false
            }
        }

        switch command {
        case let .paste(index):
            return handlePaste(index: index)
        case let .search(query):
            return handleSearch(query: query)
        case .export:
            return handleExport()
        case .history:
            return handleShowHistory()
        case .clear:
            return handleClear()
        case let .snippet(name, values):
            return handleSnippet(name: name, values: values)
        case let .copy(text):
            return handleCopy(text: text)
        }
    }

    // MARK: - Biometric Authentication

    /// Synchronous biometric authentication for URL scheme commands.
    /// Uses a semaphore to block until Touch ID completes since URL scheme
    /// handlers need a synchronous return value.
    private func authenticateSync() -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // No biometrics available — allow access (same as popover behavior)
            return true
        }

        let semaphore = DispatchSemaphore(value: 0)
        var success = false

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Authenticate to allow external clipboard access"
        ) { result, _ in
            success = result
            semaphore.signal()
        }

        semaphore.wait()
        return success
    }

    // MARK: - Command Handlers

    /// Pastes item at specified index (requires confirmation)
    private func handlePaste(index: Int) -> Bool {
        guard let clipboardManager = ClipboardManager.shared else { return false }
        guard index >= 0, index < clipboardManager.history.count else {
            print("URLSchemeHandler: Index \(index) out of bounds")
            return false
        }

        let item = clipboardManager.history[index]
        let preview = String(item.preview.prefix(60))

        guard showConfirmation(
            title: "External Paste Request",
            message: "An external source wants to paste item #\(index + 1):\n\n\"\(preview)\""
        ) else { return false }

        clipboardManager.paste(item: item)
        return true
    }

    /// Opens search with specified query
    private func handleSearch(query: String) -> Bool {
        NotificationCenter.default.post(name: .openSearchWithQuery, object: query)
        return true
    }

    /// Triggers history export
    private func handleExport() -> Bool {
        NotificationCenter.default.post(name: .triggerExport, object: nil)
        return true
    }

    /// Shows history window
    private func handleShowHistory() -> Bool {
        NotificationCenter.default.post(name: .showHistory, object: nil)
        return true
    }

    /// Clears history with confirmation
    private func handleClear() -> Bool {
        guard let clipboardManager = ClipboardManager.shared else { return false }

        guard showConfirmation(
            title: "Clear Clipboard History?",
            message: "An external source wants to clear all clipboard history. This will permanently delete all items except pinned ones.",
            confirmTitle: "Clear"
        ) else { return false }

        clipboardManager.clearHistory()
        return true
    }

    /// Pastes snippet by name (requires confirmation)
    private func handleSnippet(name: String, values: [String: String]) -> Bool {
        let snippetManager = SnippetManager.shared

        guard let snippet = snippetManager.snippets.first(where: {
            $0.name.lowercased() == name.lowercased()
        }) else {
            print("URLSchemeHandler: Snippet '\(name)' not found")
            return false
        }

        // Merge placeholder values from URL
        var mergedValues = values
        let placeholders = snippetManager.extractPlaceholders(from: snippet.template)
        for placeholder in placeholders where mergedValues[placeholder] == nil {
            mergedValues[placeholder] = ""
        }

        let expanded = snippetManager.expand(snippet: snippet, values: mergedValues)
        let preview = String(expanded.prefix(60))

        guard showConfirmation(
            title: "External Snippet Request",
            message: "An external source wants to paste snippet \"\(name)\":\n\n\"\(preview)\""
        ) else { return false }

        // Set to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(expanded, forType: .string)

        #if APP_STORE
            // App Store: just copy to clipboard, user pastes manually
            SettingsModel.shared.pasteSound.play()
        #else
            // Check accessibility before attempting paste
            guard AXIsProcessTrusted() else {
                // Show permission alert — same as ClipboardManager.simulatePaste()
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "SaneClip needs Accessibility permission to paste into other apps.\n\nGo to System Settings > Privacy & Security > Accessibility and enable SaneClip."
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Cancel")
                alert.alertStyle = .warning
                if alert.runModal() == .alertFirstButtonReturn {
                    if let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(settingsURL)
                    }
                }
                return false
            }

            // Trigger paste
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let source = CGEventSource(stateID: .hidSystemState)
                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
                keyDown?.flags = .maskCommand
                keyUp?.flags = .maskCommand
                keyDown?.post(tap: .cghidEventTap)
                keyUp?.post(tap: .cghidEventTap)
            }
        #endif

        return true
    }

    /// Copies text directly to clipboard (requires confirmation)
    private func handleCopy(text: String) -> Bool {
        let preview = String(text.prefix(60))

        guard showConfirmation(
            title: "External Copy Request",
            message: "An external source wants to replace your clipboard with:\n\n\"\(preview)\""
        ) else { return false }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        SettingsModel.shared.pasteSound.play()

        return true
    }
}

// MARK: - URL Query Helper

extension URL {
    /// Gets a query parameter value by key
    func queryValue(for key: String) -> String? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems
        else {
            return nil
        }
        return queryItems.first { $0.name == key }?.value
    }
}
