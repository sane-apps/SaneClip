import Foundation
import AppKit

/// Notification names for URL scheme actions
extension Notification.Name {
    static let openSearchWithQuery = Notification.Name("SaneClipOpenSearchWithQuery")
    static let triggerExport = Notification.Name("SaneClipTriggerExport")
    static let showHistory = Notification.Name("SaneClipShowHistory")
    static let pasteAtIndex = Notification.Name("SaneClipPasteAtIndex")
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
@MainActor
final class URLSchemeHandler {

    /// Shared singleton instance
    static let shared = URLSchemeHandler()

    private init() {}

    /// Handles an incoming URL scheme request
    /// - Parameter url: The URL to handle
    /// - Returns: True if the URL was handled successfully
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme == "saneclip" else {
            print("URLSchemeHandler: Invalid scheme \(url.scheme ?? "nil")")
            return false
        }

        guard let host = url.host else {
            print("URLSchemeHandler: No host in URL")
            return false
        }

        switch host.lowercased() {
        case "paste":
            return handlePaste(url)
        case "search":
            return handleSearch(url)
        case "export":
            return handleExport()
        case "history":
            return handleShowHistory()
        case "clear":
            return handleClear()
        case "snippet":
            return handleSnippet(url)
        case "copy":
            return handleCopy(url)
        default:
            print("URLSchemeHandler: Unknown command '\(host)'")
            return false
        }
    }

    // MARK: - Command Handlers

    /// Pastes item at specified index
    /// saneclip://paste?index=0
    private func handlePaste(_ url: URL) -> Bool {
        guard let indexString = url.queryValue(for: "index"),
              let index = Int(indexString),
              let clipboardManager = ClipboardManager.shared else {
            print("URLSchemeHandler: Invalid paste index")
            return false
        }

        guard index >= 0, index < clipboardManager.history.count else {
            print("URLSchemeHandler: Index \(index) out of bounds")
            return false
        }

        let item = clipboardManager.history[index]
        clipboardManager.paste(item: item)
        return true
    }

    /// Opens search with specified query
    /// saneclip://search?q=keyword
    private func handleSearch(_ url: URL) -> Bool {
        guard let query = url.queryValue(for: "q"), !query.isEmpty else {
            print("URLSchemeHandler: Missing search query")
            return false
        }

        NotificationCenter.default.post(name: .openSearchWithQuery, object: query)
        return true
    }

    /// Triggers history export
    /// saneclip://export
    private func handleExport() -> Bool {
        NotificationCenter.default.post(name: .triggerExport, object: nil)
        return true
    }

    /// Shows history window
    /// saneclip://history
    private func handleShowHistory() -> Bool {
        NotificationCenter.default.post(name: .showHistory, object: nil)
        return true
    }

    /// Clears history with confirmation
    /// saneclip://clear
    private func handleClear() -> Bool {
        guard let clipboardManager = ClipboardManager.shared else {
            return false
        }

        // Show confirmation alert
        let alert = NSAlert()
        alert.messageText = "Clear Clipboard History?"
        alert.informativeText = "This will permanently delete all clipboard history except pinned items."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            clipboardManager.clearHistory()
            return true
        }
        return false
    }

    /// Pastes snippet by name
    /// saneclip://snippet?name=My%20Snippet
    private func handleSnippet(_ url: URL) -> Bool {
        guard let name = url.queryValue(for: "name"), !name.isEmpty else {
            print("URLSchemeHandler: Missing snippet name")
            return false
        }

        let snippetManager = SnippetManager.shared

        guard let snippet = snippetManager.snippets.first(where: {
            $0.name.lowercased() == name.lowercased()
        }) else {
            print("URLSchemeHandler: Snippet '\(name)' not found")
            return false
        }

        // Check for placeholder values in URL
        var values: [String: String] = [:]
        let placeholders = snippetManager.extractPlaceholders(from: snippet.template)
        for placeholder in placeholders {
            if let value = url.queryValue(for: placeholder) {
                values[placeholder] = value
            }
        }

        let expanded = snippetManager.expand(snippet: snippet, values: values)

        // Set to clipboard and paste
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(expanded, forType: .string)

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

        return true
    }

    /// Copies text directly to clipboard
    /// saneclip://copy?text=Hello%20World
    private func handleCopy(_ url: URL) -> Bool {
        guard let text = url.queryValue(for: "text"), !text.isEmpty else {
            print("URLSchemeHandler: Missing text to copy")
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        if SettingsModel.shared.playSounds {
            NSSound(named: .init("Pop"))?.play()
        }

        return true
    }
}

// MARK: - URL Query Helper

extension URL {
    /// Gets a query parameter value by key
    func queryValue(for key: String) -> String? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        return queryItems.first { $0.name == key }?.value
    }
}
