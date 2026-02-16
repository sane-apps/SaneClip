import SwiftUI

// MARK: - Filter Enums

enum DateFilter: String, CaseIterable {
    case all = "All Time"
    case today = "Today"
    case week = "Last 7 Days"
    case month = "Last 30 Days"

    var cutoffDate: Date? {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .all: return nil
        case .today: return calendar.startOfDay(for: now)
        case .week: return calendar.date(byAdding: .day, value: -7, to: now)
        case .month: return calendar.date(byAdding: .day, value: -30, to: now)
        }
    }
}

enum ContentTypeFilter: String, CaseIterable {
    case all = "All"
    case text = "Text"
    case url = "Links"
    case code = "Code"
    case image = "Images"
}

// MARK: - Clipboard History View

struct ClipboardHistoryView: View {
    var clipboardManager: ClipboardManager
    @State private var searchText = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isListFocused: Bool

    // Filter state
    @State private var dateFilter: DateFilter = .all
    @State private var contentTypeFilter: ContentTypeFilter = .all
    @State private var showFilters = false

    /// Check if any filters are active
    var hasActiveFilters: Bool {
        dateFilter != .all || contentTypeFilter != .all
    }

    /// All navigable items (pinned + history)
    var allItems: [ClipboardItem] {
        filteredPinned + filteredHistory
    }

    var filteredHistory: [ClipboardItem] {
        var items = clipboardManager.history

        // Apply text search (matches content and notes)
        if !searchText.isEmpty {
            items = items.filter { item in
                if case let .text(string) = item.content,
                   string.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                if let note = item.note, note.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                return false
            }
        }

        // Apply date filter
        if let cutoff = dateFilter.cutoffDate {
            items = items.filter { $0.timestamp >= cutoff }
        }

        // Apply content type filter
        items = applyContentTypeFilter(to: items)

        // Filter out pinned items from main list (they show in pinned section)
        return items.filter { !clipboardManager.isPinned($0) }
    }

    var filteredPinned: [ClipboardItem] {
        var items = clipboardManager.pinnedItems

        // Apply text search (matches content and notes)
        if !searchText.isEmpty {
            items = items.filter { item in
                if case let .text(string) = item.content,
                   string.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                if let note = item.note, note.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                return false
            }
        }

        // Apply date filter
        if let cutoff = dateFilter.cutoffDate {
            items = items.filter { $0.timestamp >= cutoff }
        }

        // Apply content type filter
        items = applyContentTypeFilter(to: items)

        return items
    }

    private func applyContentTypeFilter(to items: [ClipboardItem]) -> [ClipboardItem] {
        switch contentTypeFilter {
        case .all:
            items
        case .text:
            items.filter { item in
                if case .text = item.content {
                    return !item.isURL && !item.isCode
                }
                return false
            }
        case .url:
            items.filter(\.isURL)
        case .code:
            items.filter(\.isCode)
        case .image:
            items.filter { item in
                if case .image = item.content { return true }
                return false
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar with filter toggle
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Search clipboard history...", text: $searchText)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search")
                    .accessibilityHint("Filter clipboard items by text content")
                if !searchText.isEmpty {
                    Button(
                        action: { searchText = "" },
                        label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    )
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }

                // Filter toggle button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showFilters.toggle()
                    }
                } label: {
                    ZStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(hasActiveFilters ? Color.clipBlue : .secondary)
                        if hasActiveFilters {
                            Circle()
                                .fill(Color.clipBlue)
                                .frame(width: 8, height: 8)
                                .offset(x: 6, y: -6)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help(showFilters ? "Hide filters" : "Show filters")
            }
            .padding(8)
            .background(.background.secondary)

            // Expandable filter row
            if showFilters {
                HStack(spacing: 12) {
                    // Date filter
                    Picker("Date", selection: $dateFilter) {
                        ForEach(DateFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 110)

                    // Content type filter
                    Picker("Type", selection: $contentTypeFilter) {
                        ForEach(ContentTypeFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 80)

                    Spacer()

                    // Clear filters button
                    if hasActiveFilters {
                        Button("Clear Filters") {
                            withAnimation {
                                dateFilter = .all
                                contentTypeFilter = .all
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(Color.clipBlue)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.background.tertiary)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider()

            // History list
            if filteredHistory.isEmpty, filteredPinned.isEmpty {
                let title = hasActiveFilters
                    ? "No Matches"
                    : (searchText.isEmpty ? "No Clipboard History" : "No Results")
                let icon = hasActiveFilters
                    ? "line.3.horizontal.decrease.circle"
                    : (searchText.isEmpty ? "clipboard" : "magnifyingglass")
                let desc = hasActiveFilters
                    ? "Try different filter settings"
                    : (searchText.isEmpty ? "Copy something to see it here" : "Try a different search")
                ContentUnavailableView(title, systemImage: icon, description: Text(desc))
            } else {
                List {
                    // Pinned section (drag to reorder)
                    if !filteredPinned.isEmpty {
                        Section("Pinned") {
                            ForEach(Array(filteredPinned.enumerated()), id: \.element.id) { index, item in
                                ClipboardItemRow(
                                    item: item,
                                    isPinned: true,
                                    clipboardManager: clipboardManager,
                                    isSelected: index == selectedIndex
                                )
                            }
                            .onMove { source, destination in
                                clipboardManager.movePinnedItems(from: source, to: destination)
                            }
                        }
                    }

                    // Recent section
                    Section(filteredPinned.isEmpty ? "" : "Recent") {
                        ForEach(Array(filteredHistory.enumerated()), id: \.element.id) { index, item in
                            let globalIndex = filteredPinned.count + index
                            ClipboardItemRow(
                                item: item,
                                isPinned: false,
                                clipboardManager: clipboardManager,
                                shortcutHint: index < 9 ? "⌘⌃\(index + 1)" : nil,
                                isSelected: globalIndex == selectedIndex
                            )
                        }
                    }
                }
                .listStyle(.plain)
                .focused($isListFocused)
                .onKeyPress(.downArrow) { moveSelection(by: 1); return .handled }
                .onKeyPress(.upArrow) { moveSelection(by: -1); return .handled }
                .onKeyPress(characters: CharacterSet(charactersIn: "jJ")) { _ in
                    moveSelection(by: 1); return .handled
                }
                .onKeyPress(characters: CharacterSet(charactersIn: "kK")) { _ in
                    moveSelection(by: -1); return .handled
                }
                .onKeyPress(.return) { pasteSelectedItem(); return .handled }
            }

            Divider()

            // Footer
            HStack {
                Text("\(clipboardManager.history.count) items")
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.85))
                    .accessibilityLabel("\(clipboardManager.history.count) clipboard items")

                // Active filter indicator
                if hasActiveFilters {
                    Text("(\(allItems.count) shown)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Paste stack indicator
                if !clipboardManager.pasteStack.isEmpty {
                    Divider()
                        .frame(height: 14)

                    HStack(spacing: 4) {
                        Image(systemName: "square.stack.3d.up")
                            .font(.caption)
                        Text("\(clipboardManager.pasteStack.count)")
                            .font(.subheadline.monospacedDigit())
                    }
                    .foregroundStyle(.orange)
                    .help("Items in paste stack")

                    Button("Paste") {
                        clipboardManager.pasteFromStack()
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline)
                    .foregroundStyle(.orange)

                    Button("Clear") {
                        clipboardManager.clearPasteStack()
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button(
                    action: { SettingsWindowController.open() },
                    label: { Image(systemName: "gear") }
                )
                .buttonStyle(.plain)
                .help("Settings")
                .accessibilityLabel("Open settings")

                Button("Clear All") {
                    clipboardManager.clearHistory()
                }
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.85))
                .accessibilityLabel("Clear all clipboard history")
                .accessibilityHint("Removes all items from history. This cannot be undone.")
            }
            .padding(8)
        }
        .onAppear {
            selectedIndex = 0
            isListFocused = true
        }
    }

    private func moveSelection(by offset: Int) {
        let itemCount = allItems.count
        guard itemCount > 0 else { return }
        selectedIndex = max(0, min(itemCount - 1, selectedIndex + offset))
    }

    private func pasteSelectedItem() {
        guard selectedIndex >= 0, selectedIndex < allItems.count else { return }
        let item = allItems[selectedIndex]
        clipboardManager.paste(item: item)
    }
}
