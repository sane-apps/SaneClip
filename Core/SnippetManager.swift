import Foundation
import AppKit
import os.log

struct SnippetLibrarySection: Identifiable, Equatable {
    static let uncategorizedTitle = "Uncategorized"

    let title: String
    let snippets: [Snippet]

    var id: String { title }
}

/// Manages snippet storage, retrieval, and expansion
@MainActor
@Observable
class SnippetManager {
    static let shared = SnippetManager()

    var snippets: [Snippet] = []

    private let logger = Logger(subsystem: "com.saneclip.app", category: "SnippetManager")

    private init() {
        loadSnippets()
    }

    // MARK: - Placeholder Handling

    /// Placeholder pattern: {{name}}
    private let placeholderPattern = #"\{\{([^}]+)\}\}"#

    /// Extract all placeholder names from a template
    func extractPlaceholders(from template: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: placeholderPattern) else {
            return []
        }

        let range = NSRange(template.startIndex..., in: template)
        let matches = regex.matches(in: template, range: range)

        var placeholders: [String] = []
        for match in matches {
            if let placeholderRange = Range(match.range(at: 1), in: template) {
                let placeholder = String(template[placeholderRange])
                if !placeholders.contains(placeholder) {
                    placeholders.append(placeholder)
                }
            }
        }

        return placeholders
    }

    /// Expand a snippet by replacing placeholders with values
    /// Special placeholders: {{date}}, {{time}}, {{clipboard}}
    func expand(snippet: Snippet, values: [String: String] = [:]) -> String {
        var result = snippet.template

        // Handle special placeholders first
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        result = result.replacingOccurrences(of: "{{date}}", with: dateFormatter.string(from: Date()))

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        result = result.replacingOccurrences(of: "{{time}}", with: timeFormatter.string(from: Date()))

        // Current clipboard content
        if result.contains("{{clipboard}}") {
            let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
            result = result.replacingOccurrences(of: "{{clipboard}}", with: clipboard)
        }

        // Replace user-provided values
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }

        return result
    }

    /// Check if snippet has any user-prompted placeholders (not special ones)
    func hasUserPlaceholders(snippet: Snippet) -> Bool {
        !userPlaceholders(in: snippet).isEmpty
    }

    func userPlaceholders(in snippet: Snippet) -> [String] {
        let all = extractPlaceholders(from: snippet.template)
        let special = Set(["date", "time", "clipboard"])
        return all.filter { !special.contains($0.lowercased()) }
    }

    // MARK: - CRUD Operations

    func add(_ snippet: Snippet) {
        snippets.append(snippet)
        saveSnippets()
        logger.debug("Added snippet: \(snippet.name)")
    }

    func update(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
            saveSnippets()
            logger.debug("Updated snippet: \(snippet.name)")
        }
    }

    func delete(id: UUID) {
        snippets.removeAll { $0.id == id }
        saveSnippets()
        logger.debug("Deleted snippet: \(id)")
    }

    func incrementUseCount(for snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index].useCount += 1
            snippets[index].lastUsedAt = Date()
            saveSnippets()
        }
    }

    // MARK: - Search

    func search(_ query: String) -> [Snippet] {
        guard !query.isEmpty else { return snippets }
        return snippets.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.template.localizedCaseInsensitiveContains(query) ||
            ($0.category?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    /// Get all unique categories
    var categories: [String] {
        Array(Set(snippets.compactMap { $0.category })).sorted()
    }

    nonisolated static func librarySections(for snippets: [Snippet]) -> [SnippetLibrarySection] {
        let grouped = Dictionary(grouping: snippets) { snippet in
            let category = snippet.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return category.isEmpty ? SnippetLibrarySection.uncategorizedTitle : category
        }

        return grouped.keys.sorted { lhs, rhs in
            if lhs == SnippetLibrarySection.uncategorizedTitle { return false }
            if rhs == SnippetLibrarySection.uncategorizedTitle { return true }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }.map { title in
            SnippetLibrarySection(
                title: title,
                snippets: (grouped[title] ?? []).sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
            )
        }
    }

    // MARK: - Persistence

    private var snippetsFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("SaneClip", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("snippets.json")
    }

    private func saveSnippets() {
        do {
            let data = try JSONEncoder().encode(snippets)
            try data.write(to: snippetsFileURL, options: [.atomic])
            logger.debug("Saved \(self.snippets.count) snippets")
        } catch {
            logger.error("Failed to save snippets: \(error.localizedDescription)")
        }
    }

    private func loadSnippets() {
        guard FileManager.default.fileExists(atPath: snippetsFileURL.path) else {
            // Create sample snippets for new users
            createSampleSnippets()
            return
        }

        do {
            let data = try Data(contentsOf: snippetsFileURL)
            snippets = try JSONDecoder().decode([Snippet].self, from: data)
            logger.debug("Loaded \(self.snippets.count) snippets")
        } catch {
            logger.error("Failed to load snippets: \(error.localizedDescription)")
        }
    }

    private func createSampleSnippets() {
        snippets = [
            Snippet(
                name: "Email Signature",
                template: """
                Best regards,
                {{name}}

                Sent on {{date}}
                """,
                category: "Email"
            ),
            Snippet(
                name: "Meeting Notes",
                template: """
                ## Meeting Notes - {{date}}

                **Attendees:** {{attendees}}

                ### Agenda
                -

                ### Action Items
                -
                """,
                category: "Work"
            ),
            Snippet(
                name: "Current Date",
                template: "{{date}}",
                category: "Utility"
            )
        ]
        saveSnippets()
    }
}
