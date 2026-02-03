import SwiftUI

struct SnippetsSettingsView: View {
    @State private var snippetManager = SnippetManager.shared
    @State private var searchText = ""
    @State private var selectedSnippet: Snippet?
    @State private var showAddSheet = false
    @State private var showEditSheet = false

    var filteredSnippets: [Snippet] {
        snippetManager.search(searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search snippets...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }, label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    })
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.background.secondary)

            Divider()

            if filteredSnippets.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Snippets" : "No Results",
                    systemImage: searchText.isEmpty ? "text.quote" : "magnifyingglass",
                    description: Text(
                        searchText.isEmpty
                            ? "Create snippets to quickly paste common text"
                            : "Try a different search"
                    )
                )
            } else {
                List(selection: $selectedSnippet) {
                    ForEach(filteredSnippets) { snippet in
                        SnippetRow(snippet: snippet)
                            .tag(snippet)
                            .contextMenu {
                                Button("Edit") {
                                    selectedSnippet = snippet
                                    showEditSheet = true
                                }
                                Button("Duplicate") {
                                    duplicateSnippet(snippet)
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    snippetManager.delete(id: snippet.id)
                                }
                            }
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // Footer with add button
            HStack {
                Text("\(snippetManager.snippets.count) snippets")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: { showAddSheet = true }, label: {
                    Label("Add Snippet", systemImage: "plus")
                })
                .buttonStyle(.plain)
            }
            .padding(8)
        }
        .sheet(isPresented: $showAddSheet) {
            SnippetEditorSheet(
                mode: .add,
                onSave: { snippet in
                    snippetManager.add(snippet)
                    showAddSheet = false
                },
                onCancel: { showAddSheet = false }
            )
        }
        .sheet(isPresented: $showEditSheet) {
            if let snippet = selectedSnippet {
                SnippetEditorSheet(
                    mode: .edit(snippet),
                    onSave: { updated in
                        snippetManager.update(updated)
                        showEditSheet = false
                    },
                    onCancel: { showEditSheet = false }
                )
            }
        }
    }

    private func duplicateSnippet(_ snippet: Snippet) {
        let copy = Snippet(
            name: "\(snippet.name) (Copy)",
            template: snippet.template,
            shortcut: nil,
            category: snippet.category
        )
        snippetManager.add(copy)
    }
}

// MARK: - Snippet Row

struct SnippetRow: View {
    let snippet: Snippet

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(snippet.name)
                    .font(.headline)

                if let category = snippet.category {
                    Text(category)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }

                Spacer()

                if snippet.useCount > 0 {
                    Text("\(snippet.useCount)x")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(snippet.template)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Snippet Editor Sheet

struct SnippetEditorSheet: View {
    enum Mode {
        case add
        case edit(Snippet)

        var title: String {
            switch self {
            case .add: return "New Snippet"
            case .edit: return "Edit Snippet"
            }
        }
    }

    let mode: Mode
    let onSave: (Snippet) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var template: String = ""
    @State private var category: String = ""
    @State private var shortcut: String = ""

    private var snippet: Snippet? {
        if case .edit(let existingSnippet) = mode { return existingSnippet }
        return nil
    }

    private var placeholders: [String] {
        SnippetManager.shared.extractPlaceholders(from: template)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(mode.title)
                .font(.headline)

            Form {
                TextField("Name", text: $name)

                TextField("Category (optional)", text: $category)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Template")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $template)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 150)
                        .border(Color.secondary.opacity(0.3), width: 1)
                }

                // Placeholder help
                VStack(alignment: .leading, spacing: 8) {
                    Text("Placeholders")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        PlaceholderChip(text: "{{date}}", description: "Current date")
                        PlaceholderChip(text: "{{time}}", description: "Current time")
                        PlaceholderChip(text: "{{clipboard}}", description: "Clipboard")
                        PlaceholderChip(text: "{{name}}", description: "User prompt")
                    }
                    .font(.caption2)
                }

                // Live preview
                if !template.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preview")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(SnippetManager.shared.expand(
                            snippet: Snippet(name: "", template: template)
                        ))
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    }
                }

                // Detected placeholders
                if !placeholders.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Detected Placeholders")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            ForEach(placeholders, id: \.self) { placeholder in
                                Text("{{\(placeholder)}}")
                                    .font(.caption2.monospaced())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveSnippet()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || template.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 450)
        .onAppear {
            if let existingSnippet = snippet {
                name = existingSnippet.name
                template = existingSnippet.template
                category = existingSnippet.category ?? ""
                shortcut = existingSnippet.shortcut ?? ""
            }
        }
    }

    private func saveSnippet() {
        let newSnippet = Snippet(
            id: snippet?.id ?? UUID(),
            name: name,
            template: template,
            shortcut: shortcut.isEmpty ? nil : shortcut,
            category: category.isEmpty ? nil : category,
            createdAt: snippet?.createdAt ?? Date(),
            lastUsedAt: snippet?.lastUsedAt,
            useCount: snippet?.useCount ?? 0
        )
        onSave(newSnippet)
    }
}

// MARK: - Placeholder Chip

struct PlaceholderChip: View {
    let text: String
    let description: String

    var body: some View {
        VStack(spacing: 2) {
            Text(text)
                .font(.caption2.monospaced())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(4)

            Text(description)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }
}
