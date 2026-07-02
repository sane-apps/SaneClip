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
        shouldHandleListShortcuts(
            hasAttachedSheet: hasAttachedSheet,
            firstResponderIsTextInput: isTextInputResponder(firstResponder)
        )
    }

    static func shouldHandleListShortcuts(hasAttachedSheet: Bool, firstResponderIsTextInput: Bool) -> Bool {
        !hasAttachedSheet && !firstResponderIsTextInput
    }

    static func shouldFocusSearch(firstResponder: NSResponder?) -> Bool {
        shouldFocusSearch(firstResponderIsTextInput: isTextInputResponder(firstResponder))
    }

    static func shouldFocusSearch(firstResponderIsTextInput: Bool) -> Bool {
        !firstResponderIsTextInput
    }

    private static func isTextInputResponder(_ firstResponder: NSResponder?) -> Bool {
        (firstResponder is NSTextView) || (firstResponder is NSTextField)
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
    static let popoverWidth: CGFloat = 320
    static let popoverMinHeight: CGFloat = 500

    /// Bounds for the free-floating, resizable history window (Settings → open as floating window).
    /// Kept modest so the window stays usable, per Glenn's "not infinite but flexible" request.
    static let windowMinWidth: CGFloat = 300
    static let windowMinHeight: CGFloat = 360
    static let windowMaxWidth: CGFloat = 760
    static let windowMaxHeight: CGFloat = 1400

    enum FocusTarget: Hashable {
        case search
        case list
        case settingsButton
        case smartClearButton
    }

    var clipboardManager: ClipboardManager
    var licenseService: LicenseService?

    // Render/preview seams — let tests screenshot specific UI states. Defaults
    // preserve production behavior (all false/empty).
    var previewInitialShowFilters = false
    var previewInitialMergeQueueIDs: Set<UUID> = []
    var previewInitialShowPasteStackPanel = false

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
    @State private var showSmartClearConfirmation = false
    @State private var editingStackTitleID: UUID?
    @State private var editingStackNoteID: UUID?
    @State private var stackTitleDraft = ""
    @State private var stackNoteDraft = ""

    private var isPro: Bool {
        licenseService?.isPro == true
    }

    private var isAtFreeLimit: Bool {
        !isPro && clipboardManager.history.count >= ClipboardManager.freeHistoryCap
    }

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

    private var hasScopedView: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasActiveFilters
    }

    private var visibleItemIDs: Set<UUID> {
        Set(allItems.map(\.id))
    }

    private var smartClearPlan: ClipboardManager.HistoryClearPlan {
        clipboardManager.smartClearPlan()
    }

    private var visibleSmartClearPlan: ClipboardManager.HistoryClearPlan {
        clipboardManager.smartClearPlan(matching: visibleItemIDs)
    }

    private var shouldOfferVisibleSmartClear: Bool {
        hasScopedView &&
            visibleSmartClearPlan.removableCount > 0 &&
            visibleSmartClearPlan.removableCount != smartClearPlan.removableCount
    }

    private var smartClearMessage: String {
        if smartClearPlan.protectedCount > 0 {
            return "Keeps pinned, tagged, noted, and non-default collection items. \(smartClearPlan.protectedCount) protected item\(smartClearPlan.protectedCount == 1 ? "" : "s") stay in history."
        }
        return "Keeps pinned, tagged, noted, and non-default collection items."
    }

    var filteredHistory: [ClipboardItem] {
        var items = clipboardManager.history

        // Apply text search (matches content and notes)
        if !searchText.isEmpty {
            items = items.filter { $0.matchesSearch(searchText) }
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
            items = items.filter { $0.matchesSearch(searchText) }
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
                HistoryFilterBar(
                    dateFilter: $dateFilter,
                    contentTypeFilter: $contentTypeFilter,
                    selectedCollection: $selectedCollection,
                    selectedTag: $selectedTag,
                    savedPresets: $savedPresets,
                    showSavePresetSheet: $showSavePresetSheet,
                    presetName: $presetName,
                    allCollections: allCollections,
                    allTags: allTags,
                    hasActiveFilters: hasActiveFilters,
                    onApplyPreset: applyPreset,
                    onPersistPresets: persistSavedPresets,
                    onClearFilters: clearFilters
                )
            }

            Divider()

            // History list
            historyList

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
                            Text("Pro")
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
                HistoryPasteStackPanel(
                    clipboardManager: clipboardManager,
                    editingStackTitleID: $editingStackTitleID,
                    editingStackNoteID: $editingStackNoteID,
                    stackTitleDraft: $stackTitleDraft,
                    stackNoteDraft: $stackNoteDraft
                )
            }

            Divider()

            HistoryFooterView(
                clipboardManager: clipboardManager,
                licenseService: licenseService,
                hasActiveFilters: hasActiveFilters,
                shownCount: allItems.count,
                smartClearRemovableCount: smartClearPlan.removableCount,
                mergeQueueIDs: $mergeQueueIDs,
                showPasteStackPanel: $showPasteStackPanel,
                showSmartClearConfirmation: $showSmartClearConfirmation,
                focusedTarget: $focusedTarget,
                onMerge: mergeQueuedItems
            )
        }
        .background(historyKeyboardShortcuts)
        .onAppear {
            selectedIndex = 0
            focusedTarget = .list
            loadSavedPresets()
            if previewInitialShowFilters { showFilters = true }
            if !previewInitialMergeQueueIDs.isEmpty { mergeQueueIDs = previewInitialMergeQueueIDs }
            if previewInitialShowPasteStackPanel { showPasteStackPanel = true }
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
            .frame(width: Self.popoverWidth)
        }
        .confirmationDialog("Smart Clear", isPresented: $showSmartClearConfirmation, titleVisibility: .visible) {
            if shouldOfferVisibleSmartClear {
                Button("Clear Visible Disposable Items (\(visibleSmartClearPlan.removableCount))", role: .destructive) {
                    _ = clipboardManager.clearSmartHistory(matching: visibleItemIDs)
                }
            }

            if smartClearPlan.removableCount > 0 {
                Button("Clear Disposable Items (\(smartClearPlan.removableCount))", role: .destructive) {
                    _ = clipboardManager.clearSmartHistory()
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(smartClearMessage)
        }
    }

    /// Extracted from `body` so the view and the list each type-check on their
    /// own (a long modifier chain inline with the rest of body times out).
    @ViewBuilder
    private var historyList: some View {
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
            ScrollViewReader { proxy in
                List {
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

                    Section(filteredPinned.isEmpty ? "" : "Recent") {
                        ForEach(Array(filteredHistory.enumerated()), id: \.element.id) { index, item in
                            let globalIndex = filteredPinned.count + index
                            ClipboardItemRow(
                                item: item,
                                isPinned: false,
                                clipboardManager: clipboardManager,
                                licenseService: licenseService,
                                shortcutHint: quickPasteHint(for: index),
                                isSelected: globalIndex == selectedIndex,
                                isQueuedForMerge: mergeQueueIDs.contains(item.id),
                                onToggleMergeQueue: { toggleMergeQueue(id: item.id) }
                            )
                        }
                    }
                }
                .listStyle(.plain)
                .focused($focusedTarget, equals: .list)
                .onChange(of: selectedIndex) { _, newIndex in
                    guard newIndex >= 0, newIndex < allItems.count else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(allItems[newIndex].id, anchor: .center)
                    }
                }
                .modifier(HistoryListKeyboardShortcuts(
                    canHandle: shouldHandleListShortcuts,
                    move: moveSelection,
                    jumpToTop: { selectedIndex = 0 },
                    jumpToBottom: { selectedIndex = max(0, allItems.count - 1) },
                    selectContentFilter: applyContentTypeShortcut,
                    togglePin: togglePinSelected,
                    paste: pasteSelectedItem,
                    focusSearch: focusSearchFromList,
                    escape: handleEscape,
                    delete: deleteSelectedItem
                ))
            }
        }
    }

    private func applyContentTypeShortcut(_ characters: String) {
        switch characters {
        case "1": contentTypeFilter = .all
        case "2": contentTypeFilter = .text
        case "3": contentTypeFilter = .url
        case "4": contentTypeFilter = .code
        case "5": contentTypeFilter = .image
        default: break
        }
    }

    private func focusSearchFromList() {
        let keyWindow = NSApp.keyWindow
        guard HistoryShortcutGate.shouldFocusSearch(firstResponder: keyWindow?.firstResponder) else { return }
        focusedTarget = .search
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

    private func togglePinSelected() {
        guard selectedIndex >= 0, selectedIndex < allItems.count else { return }
        // Pinning moves the item between sections, so re-anchor the selection to
        // the same item by id (keeps the highlight — and auto-scroll — on it).
        let item = allItems[selectedIndex]
        clipboardManager.togglePin(item: item)
        if let newIndex = allItems.firstIndex(where: { $0.id == item.id }) {
            selectedIndex = newIndex
        } else {
            selectedIndex = min(selectedIndex, max(0, allItems.count - 1))
        }
    }

    /// The ⌘⌃N quick-paste shortcuts paste `history[N]` (raw). Only advertise the
    /// hint when the visible Recent order actually matches that — i.e. no pinned
    /// items and no active search/filter — so the badge never lies.
    private func quickPasteHint(for index: Int) -> String? {
        guard index < 9, clipboardManager.pinnedItems.isEmpty, !hasScopedView else { return nil }
        return "⌘⌃\(index + 1)"
    }

    private func clearFilters() {
        withAnimation {
            dateFilter = .all
            contentTypeFilter = .all
            selectedCollection = "All Collections"
            selectedTag = "All Tags"
        }
    }

    /// Escape: peel back state, then dismiss. Clears search, then filters, then
    /// closes the floating window (the popover dismisses itself on Escape).
    private func handleEscape() -> KeyPress.Result {
        if !searchText.isEmpty {
            searchText = ""
            return .handled
        }
        if hasActiveFilters {
            clearFilters()
            return .handled
        }
        if SettingsModel.shared.useFloatingHistoryWindow,
           let window = NSApp.keyWindow, window.title == "SaneClip History" {
            window.close()
            return .handled
        }
        return .ignored
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
