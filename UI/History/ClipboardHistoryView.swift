// swiftlint:disable file_length
import SaneUI
import SwiftUI

// MARK: - Filter Enums

enum DateFilter: String, CaseIterable, Codable {
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

enum ContentTypeFilter: String, CaseIterable, Codable {
    case all = "All"
    case text = "Text"
    case url = "Links"
    case code = "Code"
    case image = "Images"
}

enum HistoryShortcutGate {
    static func shouldHandleListShortcuts(hasAttachedSheet: Bool, firstResponder: NSResponder?) -> Bool {
        guard !hasAttachedSheet else { return false }
        guard !(firstResponder is NSTextView), !(firstResponder is NSTextField) else { return false }
        return true
    }

    static func shouldFocusSearch(firstResponder: NSResponder?) -> Bool {
        !(firstResponder is NSTextView) && !(firstResponder is NSTextField)
    }
}

struct HistoryFilterPreset: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var dateFilter: DateFilter
    var contentTypeFilter: ContentTypeFilter
    var collectionFilter: String
    var tagFilter: String

    init(
        id: UUID = UUID(),
        name: String,
        dateFilter: DateFilter,
        contentTypeFilter: ContentTypeFilter,
        collectionFilter: String,
        tagFilter: String
    ) {
        self.id = id
        self.name = name
        self.dateFilter = dateFilter
        self.contentTypeFilter = contentTypeFilter
        self.collectionFilter = collectionFilter
        self.tagFilter = tagFilter
    }
}

// MARK: - Clipboard History View

struct ClipboardHistoryView: View {
    enum FocusTarget: Hashable {
        case search
        case list
        case settingsButton
        case clearAllButton
    }

    var clipboardManager: ClipboardManager
    var licenseService: LicenseService?
    @State private var searchText = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var focusedTarget: FocusTarget?

    // Filter state
    @State private var dateFilter: DateFilter = .all
    @State private var contentTypeFilter: ContentTypeFilter = .all
    @State private var selectedCollection: String = "All Collections"
    @State private var selectedTag: String = "All Tags"
    @State private var savedPresets: [HistoryFilterPreset] = []
    @State private var showSavePresetSheet = false
    @State private var presetName = ""
    @State private var mergeQueueIDs: Set<UUID> = []
    @State private var showFilters = false
    @State private var showPasteStackPanel = false
    @State private var editingStackTitleID: UUID?
    @State private var editingStackNoteID: UUID?
    @State private var stackTitleDraft = ""
    @State private var stackNoteDraft = ""

    private var isPro: Bool { licenseService?.isPro == true }
    private var isAtFreeLimit: Bool { !isPro && clipboardManager.history.count >= ClipboardManager.freeHistoryCap }

    /// Check if any filters are active
    var hasActiveFilters: Bool {
        dateFilter != .all ||
            contentTypeFilter != .all ||
            selectedCollection != "All Collections" ||
            selectedTag != "All Tags"
    }

    private var allCollections: [String] {
        ["All Collections"] + clipboardManager.availableCollections()
    }

    private var allTags: [String] {
        let tags = Set((clipboardManager.history + clipboardManager.pinnedItems).flatMap(\.tags))
        return ["All Tags"] + tags.sorted()
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

        if selectedCollection != "All Collections" {
            items = items.filter { $0.collection == selectedCollection }
        }

        if selectedTag != "All Tags" {
            items = items.filter { $0.tags.contains(selectedTag) }
        }

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

        if selectedCollection != "All Collections" {
            items = items.filter { $0.collection == selectedCollection }
        }

        if selectedTag != "All Tags" {
            items = items.filter { $0.tags.contains(selectedTag) }
        }

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

    private func shouldHandleListShortcuts() -> Bool {
        let keyWindow = NSApp.keyWindow
        return HistoryShortcutGate.shouldHandleListShortcuts(
            hasAttachedSheet: keyWindow?.attachedSheet != nil,
            firstResponder: keyWindow?.firstResponder
        )
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
                    .focused($focusedTarget, equals: .search)
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

                Menu {
                    Button("Pause 5 minutes") { clipboardManager.pauseCapture(minutes: 5) }
                    Button("Pause 15 minutes") { clipboardManager.pauseCapture(minutes: 15) }
                    Button("Pause 60 minutes") { clipboardManager.pauseCapture(minutes: 60) }
                    Divider()
                    Button("Resume Capture") { clipboardManager.resumeCapture() }
                    Divider()
                    Button("Ignore Next Copy") { clipboardManager.ignoreNextCopy() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: clipboardManager.isCapturePaused ? "pause.circle.fill" : "pause.circle")
                        if let remaining = clipboardManager.capturePauseRemainingText {
                            Text(remaining)
                                .font(.caption2.monospacedDigit())
                        }
                    }
                    .foregroundStyle(clipboardManager.isCapturePaused ? Color.orange : .secondary)
                }
                .buttonStyle(.plain)
                .help(clipboardManager.isCapturePaused ? "Capture paused" : "Pause capture")
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

                    Picker("Collection", selection: $selectedCollection) {
                        ForEach(allCollections, id: \.self) { collection in
                            Text(collection).tag(collection)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 130)

                    Picker("Tag", selection: $selectedTag) {
                        ForEach(allTags, id: \.self) { tag in
                            Text(tag).tag(tag)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 120)

                    if !savedPresets.isEmpty {
                        Menu("Saved") {
                            ForEach(savedPresets) { preset in
                                Button(preset.name) {
                                    applyPreset(preset)
                                }
                            }
                            Divider()
                            Button("Clear Saved Presets") {
                                savedPresets = []
                                persistSavedPresets()
                            }
                        }
                        .menuStyle(.borderlessButton)
                    }

                    Spacer()

                    Button("Save Current") {
                        presetName = ""
                        showSavePresetSheet = true
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(Color.clipBlue)

                    // Clear filters button
                    if hasActiveFilters {
                        Button("Clear Filters") {
                            withAnimation {
                                dateFilter = .all
                                contentTypeFilter = .all
                                selectedCollection = "All Collections"
                                selectedTag = "All Tags"
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
                                    licenseService: licenseService,
                                    isSelected: index == selectedIndex,
                                    isQueuedForMerge: mergeQueueIDs.contains(item.id),
                                    onToggleMergeQueue: { toggleMergeQueue(id: item.id) }
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
                                licenseService: licenseService,
                                shortcutHint: index < 9 ? "⌘⌃\(index + 1)" : nil,
                                isSelected: globalIndex == selectedIndex,
                                isQueuedForMerge: mergeQueueIDs.contains(item.id),
                                onToggleMergeQueue: { toggleMergeQueue(id: item.id) }
                            )
                        }
                    }
                }
                .listStyle(.plain)
                .focused($focusedTarget, equals: .list)
                .onKeyPress(.downArrow) {
                    guard shouldHandleListShortcuts() else { return .ignored }
                    moveSelection(by: 1)
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    guard shouldHandleListShortcuts() else { return .ignored }
                    moveSelection(by: -1)
                    return .handled
                }
                .onKeyPress(characters: CharacterSet(charactersIn: "jJ")) { _ in
                    guard shouldHandleListShortcuts() else { return .ignored }
                    moveSelection(by: 1)
                    return .handled
                }
                .onKeyPress(characters: CharacterSet(charactersIn: "kK")) { _ in
                    guard shouldHandleListShortcuts() else { return .ignored }
                    moveSelection(by: -1)
                    return .handled
                }
                .onKeyPress(characters: CharacterSet(charactersIn: "12345")) { keyPress in
                    guard shouldHandleListShortcuts() else { return .ignored }
                    switch keyPress.characters {
                    case "1": contentTypeFilter = .all
                    case "2": contentTypeFilter = .text
                    case "3": contentTypeFilter = .url
                    case "4": contentTypeFilter = .code
                    case "5": contentTypeFilter = .image
                    default: break
                    }
                    return .handled
                }
                .onKeyPress(.return) {
                    guard shouldHandleListShortcuts() else { return .ignored }
                    pasteSelectedItem()
                    return .handled
                }
                .onKeyPress(characters: CharacterSet(charactersIn: "/")) { _ in
                    let keyWindow = NSApp.keyWindow
                    guard HistoryShortcutGate.shouldFocusSearch(firstResponder: keyWindow?.firstResponder) else {
                        return .ignored
                    }
                    focusedTarget = .search
                    return .handled
                }
                .onDeleteCommand {
                    guard shouldHandleListShortcuts() else { return }
                    deleteSelectedItem()
                }
            }

            // Free-tier limit banner — shown when history is at cap
            if isAtFreeLimit {
                HStack(spacing: 8) {
                    Image(systemName: "infinity")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.teal)

                    Text("50-item limit reached.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)

                    Button {
                        if let ls = licenseService {
                            ProUpsellWindow.show(feature: ProFeature.unlimitedHistory, licenseService: ls)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                            Text("Upgrade to Pro")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.teal)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.teal.opacity(0.12))
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.teal.opacity(0.25)), alignment: .top)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if isPro, showPasteStackPanel {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Paste Stack")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary.opacity(0.9))
                        Spacer()
                        Toggle("Pause", isOn: Binding(
                            get: { SettingsModel.shared.pausePasteStackConsumption },
                            set: { SettingsModel.shared.pausePasteStackConsumption = $0 }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .help("Pause consuming the stack")
                        Button("Undo") {
                            clipboardManager.undoLastPasteFromStack()
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .disabled(!clipboardManager.canUndoLastStackPaste)
                        Button("Clear") {
                            clipboardManager.clearPasteStack()
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        Toggle("Keep open while consuming", isOn: Binding(
                            get: { SettingsModel.shared.keepPasteStackOpenBetweenPastes },
                            set: { SettingsModel.shared.keepPasteStackOpenBetweenPastes = $0 }
                        ))
                        .toggleStyle(.checkbox)
                        Toggle("Auto-close when empty", isOn: Binding(
                            get: { SettingsModel.shared.autoClosePasteStackWhenEmpty },
                            set: { SettingsModel.shared.autoClosePasteStackWhenEmpty = $0 }
                        ))
                        .toggleStyle(.checkbox)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if clipboardManager.pasteStack.isEmpty {
                        Text("Paste stack is empty.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        List {
                            ForEach(Array(clipboardManager.pasteStack.enumerated()), id: \.element.id) { index, item in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text("#\(index + 1)")
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 24, alignment: .leading)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.title?.isEmpty == false ? item.title! : item.preview)
                                                .lineLimit(1)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.primary)
                                            if let note = item.note, !note.isEmpty {
                                                Text(note)
                                                    .lineLimit(1)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Button("Paste") {
                                            clipboardManager.pasteFromStackItem(id: item.id)
                                        }
                                        .buttonStyle(.plain)
                                        .font(.caption)
                                        Button("Top") {
                                            clipboardManager.movePasteStackItemToTop(id: item.id)
                                        }
                                        .buttonStyle(.plain)
                                        .font(.caption)
                                        Button {
                                            clipboardManager.movePasteStackItemUp(id: item.id)
                                        } label: {
                                            Image(systemName: "arrow.up")
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(.secondary)
                                        .help("Move up")
                                        Button {
                                            clipboardManager.movePasteStackItemDown(id: item.id)
                                        } label: {
                                            Image(systemName: "arrow.down")
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(.secondary)
                                        .help("Move down")
                                        Button(editingStackTitleID == item.id ? "Save Title" : "Rename") {
                                            if editingStackTitleID == item.id {
                                                clipboardManager.updateItemTitle(id: item.id, title: stackTitleDraft)
                                                editingStackTitleID = nil
                                            } else {
                                                editingStackTitleID = item.id
                                                stackTitleDraft = item.title ?? ""
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .font(.caption)
                                        Button(editingStackNoteID == item.id ? "Save Note" : "Note") {
                                            if editingStackNoteID == item.id {
                                                clipboardManager.updateItemNote(id: item.id, note: stackNoteDraft)
                                                editingStackNoteID = nil
                                            } else {
                                                editingStackNoteID = item.id
                                                stackNoteDraft = item.note ?? ""
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .font(.caption)
                                        Button {
                                            clipboardManager.removeFromPasteStack(id: item.id)
                                        } label: {
                                            Image(systemName: "xmark.circle")
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(.secondary)
                                        .help("Remove from stack")
                                    }

                                    if editingStackTitleID == item.id {
                                        TextField("Title", text: $stackTitleDraft)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                    if editingStackNoteID == item.id {
                                        TextField("Note", text: $stackNoteDraft)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                }
                            }
                            .onMove { source, destination in
                                clipboardManager.movePasteStackItems(from: source, to: destination)
                            }
                        }
                        .frame(height: min(220, CGFloat(max(2, clipboardManager.pasteStack.count)) * 44))
                        .listStyle(.plain)
                    }
                }
                .padding(8)
                .background(.background.tertiary)
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

                if !mergeQueueIDs.isEmpty {
                    Divider()
                        .frame(height: 14)
                    HStack(spacing: 4) {
                        Image(systemName: "link.badge.plus")
                            .font(.caption)
                        Text("\(mergeQueueIDs.count)")
                            .font(.subheadline.monospacedDigit())
                    }
                    .foregroundStyle(.teal)
                    .help("Items queued for merge")

                    Button("Merge") {
                        mergeQueuedItems()
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline)
                    .foregroundStyle(.teal)
                    .disabled(mergeQueueIDs.count < 2)

                    Button("Clear Queue") {
                        mergeQueueIDs.removeAll()
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                // Paste stack indicator
                if isPro {
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

                    Button(SettingsModel.shared.pausePasteStackConsumption ? "Paused" : "Paste") {
                        clipboardManager.pasteFromStack()
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .disabled(SettingsModel.shared.pausePasteStackConsumption || clipboardManager.pasteStack.isEmpty)

                    Button(showPasteStackPanel ? "Hide" : "Stack") {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showPasteStackPanel.toggle()
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                } else if !isPro {
                    // Paste Stack teaser for free users
                    Divider()
                        .frame(height: 14)
                    Button {
                        if let ls = licenseService {
                            ProUpsellWindow.show(feature: ProFeature.pasteStack, licenseService: ls)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                            Text("Stack")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.teal.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Unlock Paste Stack with Pro")
                }

                Spacer()

                Button(
                    action: { SettingsWindowController.open() },
                    label: { Image(systemName: "gear") }
                )
                .buttonStyle(.plain)
                .keyboardShortcut(",", modifiers: .command)
                .focusable()
                .focused($focusedTarget, equals: .settingsButton)
                .help("Settings")
                .accessibilityLabel("Open settings")

                Button("Clear All") {
                    clipboardManager.clearHistory()
                }
                .buttonStyle(.plain)
                .focusable()
                .focused($focusedTarget, equals: .clearAllButton)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.85))
                .accessibilityLabel("Clear all clipboard history")
                .accessibilityHint("Removes all items from history. This cannot be undone.")
            }
            .padding(8)
        }
        .background(historyKeyboardShortcuts)
        .onAppear {
            selectedIndex = 0
            focusedTarget = .list
            loadSavedPresets()
        }
        .onReceive(NotificationCenter.default.publisher(for: .historySearchShortcutRequested)) { _ in
            focusedTarget = .search
        }
        .onChange(of: allCollections) { _, newCollections in
            if !newCollections.contains(selectedCollection) {
                selectedCollection = "All Collections"
            }
        }
        .onChange(of: allTags) { _, newTags in
            if !newTags.contains(selectedTag) {
                selectedTag = "All Tags"
            }
        }
        .sheet(isPresented: $showSavePresetSheet) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Save Filter Preset")
                    .font(.headline)
                TextField("Preset name", text: $presetName)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("Cancel") {
                        showSavePresetSheet = false
                    }
                    Button("Save") {
                        saveCurrentPreset()
                        showSavePresetSheet = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(16)
            .frame(width: 320)
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

    private func deleteSelectedItem() {
        guard selectedIndex >= 0, selectedIndex < allItems.count else { return }
        let item = allItems[selectedIndex]
        clipboardManager.delete(item: item)
        let nextCount = max(0, allItems.count - 1)
        selectedIndex = min(selectedIndex, max(0, nextCount - 1))
    }

    private func toggleMergeQueue(id: UUID) {
        if mergeQueueIDs.contains(id) {
            mergeQueueIDs.remove(id)
        } else {
            mergeQueueIDs.insert(id)
        }
    }

    private func mergeQueuedItems() {
        guard mergeQueueIDs.count >= 2 else { return }
        let ids = allItems.map(\.id).filter { mergeQueueIDs.contains($0) }
        _ = clipboardManager.mergeItems(withIDs: ids)
        mergeQueueIDs.removeAll()
    }

    private func loadSavedPresets() {
        guard let data = UserDefaults.standard.data(forKey: "historyFilterPresets"),
              let decoded = try? JSONDecoder().decode([HistoryFilterPreset].self, from: data)
        else {
            savedPresets = []
            return
        }
        savedPresets = decoded
    }

    private func persistSavedPresets() {
        guard let data = try? JSONEncoder().encode(savedPresets) else { return }
        UserDefaults.standard.set(data, forKey: "historyFilterPresets")
    }

    private func saveCurrentPreset() {
        let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let preset = HistoryFilterPreset(
            name: name,
            dateFilter: dateFilter,
            contentTypeFilter: contentTypeFilter,
            collectionFilter: selectedCollection,
            tagFilter: selectedTag
        )
        savedPresets.removeAll { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        savedPresets.append(preset)
        savedPresets.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persistSavedPresets()
    }

    private func applyPreset(_ preset: HistoryFilterPreset) {
        dateFilter = preset.dateFilter
        contentTypeFilter = preset.contentTypeFilter
        selectedCollection = allCollections.contains(preset.collectionFilter) ? preset.collectionFilter : "All Collections"
        selectedTag = allTags.contains(preset.tagFilter) ? preset.tagFilter : "All Tags"
    }

    @ViewBuilder
    private var historyKeyboardShortcuts: some View {
        Button("") {
            focusedTarget = .search
        }
        .keyboardShortcut("f", modifiers: .command)
        .frame(width: 0, height: 0)
        .opacity(0.001)
        .accessibilityHidden(true)
    }
}
// swiftlint:enable file_length
