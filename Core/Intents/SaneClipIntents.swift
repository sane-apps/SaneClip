import AppIntents
import AppKit
import Foundation

// MARK: - Get Clipboard History Intent

/// Returns recent clipboard history items
struct GetClipboardHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Clipboard History"
    static let description: IntentDescription = "Returns recent text items from clipboard history"

    @Parameter(title: "Limit", default: 10)
    var limit: Int

    @Parameter(title: "Include Pinned Only", default: false)
    var pinnedOnly: Bool

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        guard let clipboardManager = ClipboardManager.shared else {
            return .result(value: [])
        }

        let source = pinnedOnly ? clipboardManager.pinnedItems : clipboardManager.history
        let texts = source.prefix(limit).compactMap { item -> String? in
            if case .text(let string) = item.content {
                return string
            }
            return nil
        }

        return .result(value: Array(texts))
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$limit) clipboard items") {
            \.$pinnedOnly
        }
    }
}

// MARK: - Paste Clipboard Item Intent

/// Pastes a clipboard item at the specified index
struct PasteClipboardItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Paste Clipboard Item"
    static let description: IntentDescription = "Pastes an item from clipboard history at the specified index"

    @Parameter(title: "Index", default: 0)
    var index: Int

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let clipboardManager = ClipboardManager.shared else {
            throw IntentError.clipboardUnavailable
        }

        guard index >= 0, index < clipboardManager.history.count else {
            throw IntentError.indexOutOfBounds
        }

        clipboardManager.pasteItemAt(index: index)
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Paste item at index \(\.$index)")
    }
}

// MARK: - Search Clipboard Intent

/// Searches clipboard history for matching items
struct SearchClipboardIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Clipboard"
    static let description: IntentDescription = "Searches clipboard history for items matching the query"

    @Parameter(title: "Query")
    var query: String

    @Parameter(title: "Limit", default: 5)
    var limit: Int

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        guard let clipboardManager = ClipboardManager.shared else {
            return .result(value: [])
        }

        let lowercasedQuery = query.lowercased()
        let results = clipboardManager.history
            .filter { item in
                if case .text(let string) = item.content {
                    return string.lowercased().contains(lowercasedQuery)
                }
                return false
            }
            .prefix(limit)
            .compactMap { item -> String? in
                if case .text(let string) = item.content {
                    return string
                }
                return nil
            }

        return .result(value: Array(results))
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Search for \(\.$query)") {
            \.$limit
        }
    }
}

// MARK: - Copy Text Intent

/// Copies text to the clipboard without pasting
struct CopyTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Copy to SaneClip"
    static let description: IntentDescription = "Copies text to the clipboard"

    @Parameter(title: "Text")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Copy \(\.$text) to clipboard")
    }
}

// MARK: - Clear History Intent

/// Clears all clipboard history except pinned items
struct ClearHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Clear Clipboard History"
    static let description: IntentDescription = "Clears all clipboard history except pinned items"

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let clipboardManager = ClipboardManager.shared else {
            throw IntentError.clipboardUnavailable
        }

        clipboardManager.clearHistory()
        return .result()
    }
}

// MARK: - Paste Snippet Intent

/// Pastes a saved snippet by name
struct PasteSnippetIntent: AppIntent {
    static let title: LocalizedStringResource = "Paste Snippet"
    static let description: IntentDescription = "Pastes a saved snippet by name"

    @Parameter(title: "Snippet Name")
    var snippetName: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let snippetManager = SnippetManager.shared

        guard let snippet = snippetManager.snippets.first(where: {
            $0.name.lowercased() == snippetName.lowercased()
        }) else {
            throw IntentError.snippetNotFound
        }

        // Expand with default values only (no custom placeholders via Shortcuts)
        let expanded = snippetManager.expand(snippet: snippet, values: [:])

        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(expanded, forType: .string)

        return .result(value: expanded)
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Paste snippet \(\.$snippetName)")
    }
}

// MARK: - List Snippets Intent

/// Lists all available snippet names
struct ListSnippetsIntent: AppIntent {
    static let title: LocalizedStringResource = "List Snippets"
    static let description: IntentDescription = "Returns all available snippet names"

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let snippetManager = SnippetManager.shared
        let names = snippetManager.snippets.map { $0.name }
        return .result(value: names)
    }
}

// MARK: - Intent Errors

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case clipboardUnavailable
    case indexOutOfBounds
    case snippetNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .clipboardUnavailable:
            return "Clipboard manager is not available"
        case .indexOutOfBounds:
            return "Index is out of bounds"
        case .snippetNotFound:
            return "Snippet not found"
        }
    }
}

// MARK: - App Shortcuts Provider

/// Provides discoverable App Shortcuts for Siri and Shortcuts.app
/// Note: All intents are available in Shortcuts.app even without explicit shortcuts
struct SaneClipShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetClipboardHistoryIntent(),
            phrases: [
                "Get clipboard history from \(.applicationName)",
                "Show my \(.applicationName) clipboard",
                "What's in my \(.applicationName)"
            ],
            shortTitle: "Get History",
            systemImageName: "doc.on.clipboard"
        )

        AppShortcut(
            intent: ClearHistoryIntent(),
            phrases: [
                "Clear \(.applicationName) history",
                "Delete clipboard history in \(.applicationName)"
            ],
            shortTitle: "Clear History",
            systemImageName: "trash"
        )

        AppShortcut(
            intent: ListSnippetsIntent(),
            phrases: [
                "List snippets in \(.applicationName)",
                "Show my \(.applicationName) snippets"
            ],
            shortTitle: "List Snippets",
            systemImageName: "text.quote"
        )
    }
}
