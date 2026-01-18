import SwiftUI
import AppKit
import KeyboardShortcuts
import Sparkle
import LocalAuthentication
import os.log

private let appLogger = Logger(subsystem: "com.saneclip.app", category: "App")

// MARK: - Update Service

@MainActor
class UpdateService: NSObject, ObservableObject {
    static let shared = UpdateService()

    private var updaterController: SPUStandardUpdaterController?

    override init() {
        super.init()
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        appLogger.info("Sparkle updater initialized")
    }

    func checkForUpdates() {
        appLogger.info("User triggered check for updates")
        updaterController?.checkForUpdates(nil)
    }

    var automaticallyChecksForUpdates: Bool {
        get { updaterController?.updater.automaticallyChecksForUpdates ?? false }
        set { updaterController?.updater.automaticallyChecksForUpdates = newValue }
    }
}

// MARK: - Keyboard Shortcuts Extension

extension KeyboardShortcuts.Name {
    static let showClipboardHistory = Self("showClipboardHistory")
    static let pasteAsPlainText = Self("pasteAsPlainText")
    // Quick paste shortcuts for items 1-9
    static let pasteItem1 = Self("pasteItem1")
    static let pasteItem2 = Self("pasteItem2")
    static let pasteItem3 = Self("pasteItem3")
    static let pasteItem4 = Self("pasteItem4")
    static let pasteItem5 = Self("pasteItem5")
    static let pasteItem6 = Self("pasteItem6")
    static let pasteItem7 = Self("pasteItem7")
    static let pasteItem8 = Self("pasteItem8")
    static let pasteItem9 = Self("pasteItem9")
}

// MARK: - AppDelegate

@MainActor
class SaneClipAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var clipboardManager: ClipboardManager!
    private var updateService: UpdateService!

    /// Track when user last authenticated with Touch ID (grace period)
    private var lastAuthenticationTime: Date?
    private let authGracePeriod: TimeInterval = 30.0  // seconds - stays unlocked for 30s

    func applicationDidFinishLaunching(_ notification: Notification) {
        appLogger.info("SaneClip starting...")

        // Initialize update service (Sparkle)
        updateService = UpdateService.shared

        // Apply dock visibility setting (must happen early)
        _ = SettingsModel.shared

        // Initialize clipboard manager
        clipboardManager = ClipboardManager()

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Use SF Symbol from settings
            let iconName = SettingsModel.shared.menuBarIcon
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "SaneClip")
            button.action = #selector(togglePopover)
            button.target = self
            // Right-click menu
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Listen for icon changes
        NotificationCenter.default.addObserver(
            forName: .menuBarIconChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let iconName = notification.object as? String,
               let button = self?.statusItem.button {
                button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "SaneClip")
            }
        }

        // Create right-click context menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show History", action: #selector(togglePopover), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Clear History", action: #selector(clearHistoryFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit SaneClip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = nil // We'll show it manually on right-click

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ClipboardHistoryView(clipboardManager: clipboardManager)
        )

        // Set up keyboard shortcuts
        setupKeyboardShortcuts()

        appLogger.info("SaneClip ready")

        // Show onboarding on first launch
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            showOnboarding()
        }
    }

    private func showOnboarding() {
        let onboardingView = OnboardingView()
        let hostingController = NSHostingController(rootView: onboardingView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to SaneClip"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 700, height: 480))
        window.center()
        window.isReleasedWhenClosed = false

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupKeyboardShortcuts() {
        // Set defaults if not configured
        setDefaultShortcutsIfNeeded()

        // Register handlers
        KeyboardShortcuts.onKeyUp(for: .showClipboardHistory) { [weak self] in
            Task { @MainActor in
                self?.togglePopover()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .pasteAsPlainText) { [weak self] in
            Task { @MainActor in
                self?.clipboardManager.pasteAsPlainText()
            }
        }

        // Quick paste shortcuts 1-9
        let shortcuts: [KeyboardShortcuts.Name] = [
            .pasteItem1, .pasteItem2, .pasteItem3, .pasteItem4, .pasteItem5,
            .pasteItem6, .pasteItem7, .pasteItem8, .pasteItem9
        ]
        for (index, shortcut) in shortcuts.enumerated() {
            KeyboardShortcuts.onKeyUp(for: shortcut) { [weak self] in
                Task { @MainActor in
                    self?.clipboardManager.pasteItemAt(index: index)
                }
            }
        }
    }

    private func setDefaultShortcutsIfNeeded() {
        // Show clipboard history: Cmd+Shift+V
        if KeyboardShortcuts.getShortcut(for: .showClipboardHistory) == nil {
            KeyboardShortcuts.setShortcut(.init(.v, modifiers: [.command, .shift]), for: .showClipboardHistory)
            appLogger.info("Set default shortcut: Cmd+Shift+V for clipboard history")
        }

        // Paste as plain text: Cmd+Shift+Option+V
        if KeyboardShortcuts.getShortcut(for: .pasteAsPlainText) == nil {
            KeyboardShortcuts.setShortcut(.init(.v, modifiers: [.command, .shift, .option]), for: .pasteAsPlainText)
            appLogger.info("Set default shortcut: Cmd+Shift+Option+V for paste as plain text")
        }

        // Quick paste shortcuts: Cmd+Ctrl+1 through 9
        let keys: [KeyboardShortcuts.Key] = [.one, .two, .three, .four, .five, .six, .seven, .eight, .nine]
        let shortcuts: [KeyboardShortcuts.Name] = [
            .pasteItem1, .pasteItem2, .pasteItem3, .pasteItem4, .pasteItem5,
            .pasteItem6, .pasteItem7, .pasteItem8, .pasteItem9
        ]
        for (key, shortcut) in zip(keys, shortcuts) {
            if KeyboardShortcuts.getShortcut(for: shortcut) == nil {
                KeyboardShortcuts.setShortcut(.init(key, modifiers: [.command, .control]), for: shortcut)
            }
        }
    }

    @objc private func clearHistoryFromMenu() {
        clipboardManager.clearHistory()
    }

    @objc private func openSettings() {
        SettingsWindowController.open()
    }

    // MARK: - Biometric Authentication

    private func authenticateWithBiometrics(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate to view clipboard history"
            ) { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else {
            // No biometrics available, allow access
            completion(true)
        }
    }

    @MainActor
    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        // Check if right-click
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showContextMenu()
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Check if Touch ID is required
            if SettingsModel.shared.requireTouchID {
                // Check if within grace period
                if let lastAuth = lastAuthenticationTime,
                   Date().timeIntervalSince(lastAuth) < authGracePeriod {
                    // Within grace period, no auth needed
                    showPopoverAtButton()
                } else {
                    authenticateWithBiometrics { [weak self] success in
                        if success {
                            self?.lastAuthenticationTime = Date()
                            // Small delay to let Touch ID dialog fully dismiss
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                self?.showPopoverAtButton()
                            }
                        }
                    }
                }
            } else {
                showPopoverAtButton()
            }
        }
    }

    private func showPopoverAtButton() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }

        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)

        // Position popover at the button's location
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Force correct positioning if needed
        if let popoverWindow = popover.contentViewController?.view.window {
            let popoverSize = popoverWindow.frame.size
            let newOrigin = NSPoint(
                x: screenRect.midX - popoverSize.width / 2,
                y: screenRect.minY - popoverSize.height
            )
            popoverWindow.setFrameOrigin(newOrigin)
            popoverWindow.makeKey()
        }
    }

    private func showContextMenu() {
        guard let button = statusItem.button else { return }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show History", action: #selector(showPopover), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // Add recent items
        let recentItems = Array(clipboardManager.history.prefix(5))
        if !recentItems.isEmpty {
            for (index, item) in recentItems.enumerated() {
                let menuItem = NSMenuItem(
                    title: String(item.preview.prefix(40)) + (item.preview.count > 40 ? "..." : ""),
                    action: #selector(pasteFromMenu(_:)),
                    keyEquivalent: ""
                )
                menuItem.tag = index
                menuItem.target = self
                menu.addItem(menuItem)
            }
            menu.addItem(NSMenuItem.separator())
        }

        menu.addItem(NSMenuItem(title: "Clear History", action: #selector(clearHistoryFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit SaneClip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func showPopover() {
        // Check if Touch ID is required
        if SettingsModel.shared.requireTouchID {
            // Check if within grace period
            if let lastAuth = lastAuthenticationTime,
               Date().timeIntervalSince(lastAuth) < authGracePeriod {
                // Within grace period, no auth needed
                showPopoverAtButton()
            } else {
                authenticateWithBiometrics { [weak self] success in
                    if success {
                        self?.lastAuthenticationTime = Date()
                        // Small delay to let Touch ID dialog fully dismiss
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            self?.showPopoverAtButton()
                        }
                    }
                }
            }
        } else {
            showPopoverAtButton()
        }
    }

    @objc private func pasteFromMenu(_ sender: NSMenuItem) {
        let index = sender.tag
        clipboardManager.pasteItemAt(index: index)
    }
}

// MARK: - Clipboard Manager

@MainActor
@Observable
class ClipboardManager {
    var history: [ClipboardItem] = []
    var pinnedItems: [ClipboardItem] = []
    private var lastChangeCount: Int = 0
    private var lastClipboardContent: String?
    private var lastCopyTime: Date?
    private var timer: Timer?
    private var maxHistorySize: Int { SettingsModel.shared.maxHistorySize }
    private let logger = Logger(subsystem: "com.saneclip.app", category: "ClipboardManager")

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
        startMonitoring()
        loadHistory()
    }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkClipboard()
            }
        }
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        // Privacy: Check if previous item was cleared quickly (password manager behavior)
        // Only if "Protect passwords" setting is enabled
        if SettingsModel.shared.protectPasswords,
           let lastContent = lastClipboardContent,
           let lastTime = lastCopyTime,
           Date().timeIntervalSince(lastTime) < 3.0 {
            // Previous item was cleared within 3 seconds - likely a password manager
            // Remove it from history if it exists
            history.removeAll { item in
                if case .text(let str) = item.content {
                    return str == lastContent
                }
                return false
            }
            logger.debug("Removed quick-cleared item (likely password)")
        }

        // Get source app info
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let sourceAppBundleID = frontmostApp?.bundleIdentifier
        let sourceAppName = frontmostApp?.localizedName

        // Skip excluded apps
        if SettingsModel.shared.isAppExcluded(sourceAppBundleID) {
            logger.debug("Skipping clipboard from excluded app: \(sourceAppName ?? "unknown")")
            return
        }

        // Get clipboard content
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            lastClipboardContent = string
            lastCopyTime = Date()
            addItem(ClipboardItem(
                content: .text(string),
                sourceAppBundleID: sourceAppBundleID,
                sourceAppName: sourceAppName
            ))
        } else if let image = NSImage(pasteboard: pasteboard) {
            lastClipboardContent = nil
            lastCopyTime = nil
            addItem(ClipboardItem(
                content: .image(image),
                sourceAppBundleID: sourceAppBundleID,
                sourceAppName: sourceAppName
            ))
        } else {
            // Clipboard was cleared
            lastClipboardContent = nil
            lastCopyTime = nil
        }
    }

    private func addItem(_ item: ClipboardItem) {
        // Don't add duplicates at the top
        if let first = history.first, first.contentHash == item.contentHash {
            return
        }

        // Remove existing duplicate if present
        history.removeAll { $0.contentHash == item.contentHash }

        // Add to front
        history.insert(item, at: 0)

        // Trim to max size
        if history.count > maxHistorySize {
            history = Array(history.prefix(maxHistorySize))
        }

        saveHistory()
        logger.debug("Added clipboard item, history count: \(self.history.count)")
    }

    func paste(item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.content {
        case .text(let string):
            pasteboard.setString(string, forType: .string)
        case .image(let image):
            if let tiffData = image.tiffRepresentation {
                pasteboard.setData(tiffData, forType: .tiff)
            }
        }

        // Move to front and increment paste count
        if let index = history.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = history.remove(at: index)
            updatedItem.pasteCount += 1
            history.insert(updatedItem, at: 0)
            saveHistory()
        }

        // Play a subtle sound (if enabled)
        if SettingsModel.shared.playSounds {
            NSSound(named: .init("Pop"))?.play()
        }

        // Simulate Cmd+V with longer delay to let popover close
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            self.simulatePaste()
        }
    }

    func pasteAsPlainText() {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            pasteboard.clearContents()
            pasteboard.setString(string, forType: .string)
            simulatePaste()
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V key
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    func delete(item: ClipboardItem) {
        history.removeAll { $0.id == item.id }
        pinnedItems.removeAll { $0.id == item.id }
        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    func pasteItemAt(index: Int) {
        guard index < history.count else { return }
        paste(item: history[index])
    }

    func togglePin(item: ClipboardItem) {
        if pinnedItems.contains(where: { $0.id == item.id }) {
            pinnedItems.removeAll { $0.id == item.id }
        } else {
            pinnedItems.insert(item, at: 0)
        }
        saveHistory()
    }

    func isPinned(_ item: ClipboardItem) -> Bool {
        pinnedItems.contains { $0.id == item.id }
    }

    // MARK: - Persistence

    private var historyFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("SaneClip", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("history.json")
    }

    private func saveHistory() {
        // Only save text items (images are too large)
        let textItems = history.compactMap { item -> SavedClipboardItem? in
            if case .text(let string) = item.content {
                return SavedClipboardItem(
                    id: item.id,
                    text: string,
                    timestamp: item.timestamp,
                    sourceAppBundleID: item.sourceAppBundleID,
                    sourceAppName: item.sourceAppName,
                    pasteCount: item.pasteCount
                )
            }
            return nil
        }

        do {
            let data = try JSONEncoder().encode(textItems)
            try data.write(to: historyFileURL)
        } catch {
            logger.error("Failed to save history: \(error.localizedDescription)")
        }
    }

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else { return }

        do {
            let data = try Data(contentsOf: historyFileURL)
            let items = try JSONDecoder().decode([SavedClipboardItem].self, from: data)
            history = items.map {
                ClipboardItem(
                    id: $0.id,
                    content: .text($0.text),
                    timestamp: $0.timestamp,
                    sourceAppBundleID: $0.sourceAppBundleID,
                    sourceAppName: $0.sourceAppName,
                    pasteCount: $0.pasteCount
                )
            }
        } catch {
            logger.error("Failed to load history: \(error.localizedDescription)")
        }
    }
}

// MARK: - Models

struct ClipboardItem: Identifiable {
    let id: UUID
    let content: ClipboardContent
    let timestamp: Date
    let sourceAppBundleID: String?
    let sourceAppName: String?
    var pasteCount: Int

    init(
        id: UUID = UUID(),
        content: ClipboardContent,
        timestamp: Date = Date(),
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        pasteCount: Int = 0
    ) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.pasteCount = pasteCount
    }

    /// Get the app icon for the source app
    var sourceAppIcon: NSImage? {
        guard let bundleID = sourceAppBundleID,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }

    var contentHash: String {
        switch content {
        case .text(let string):
            return "text:\(string.hashValue)"
        case .image(let image):
            return "image:\(image.tiffRepresentation?.hashValue ?? 0)"
        }
    }

    var preview: String {
        switch content {
        case .text(let string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 100 {
                return String(trimmed.prefix(100)) + "..."
            }
            return trimmed
        case .image:
            return "[Image]"
        }
    }

    var stats: String {
        switch content {
        case .text(let string):
            let words = string.split { $0.isWhitespace || $0.isNewline }.count
            let chars = string.count
            return "\(words)w · \(chars)c"
        case .image(let image):
            let size = image.size
            return "\(Int(size.width))×\(Int(size.height))"
        }
    }

    /// Compact time ago string with smart scaling
    var timeAgo: String {
        let seconds = Int(-timestamp.timeIntervalSinceNow)
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h"
        }
        let days = hours / 24
        return "\(days)d"
    }
}

enum ClipboardContent {
    case text(String)
    case image(NSImage)
}

struct SavedClipboardItem: Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let sourceAppBundleID: String?
    let sourceAppName: String?
    let pasteCount: Int

    init(
        id: UUID,
        text: String,
        timestamp: Date,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        pasteCount: Int = 0
    ) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.pasteCount = pasteCount
    }

    // Custom decoder for backward compatibility with old history files
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        sourceAppBundleID = try container.decodeIfPresent(String.self, forKey: .sourceAppBundleID)
        sourceAppName = try container.decodeIfPresent(String.self, forKey: .sourceAppName)
        pasteCount = try container.decodeIfPresent(Int.self, forKey: .pasteCount) ?? 0
    }
}

// MARK: - Clipboard History View

struct ClipboardHistoryView: View {
    let clipboardManager: ClipboardManager
    @State private var searchText = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isListFocused: Bool

    /// All navigable items (pinned + history)
    var allItems: [ClipboardItem] {
        filteredPinned + filteredHistory
    }

    var filteredHistory: [ClipboardItem] {
        let items = searchText.isEmpty ? clipboardManager.history : clipboardManager.history.filter { item in
            if case .text(let string) = item.content {
                return string.localizedCaseInsensitiveContains(searchText)
            }
            return false
        }
        // Filter out pinned items from main list (they show in pinned section)
        return items.filter { !clipboardManager.isPinned($0) }
    }

    var filteredPinned: [ClipboardItem] {
        guard searchText.isEmpty else {
            return clipboardManager.pinnedItems.filter { item in
                if case .text(let string) = item.content {
                    return string.localizedCaseInsensitiveContains(searchText)
                }
                return false
            }
        }
        return clipboardManager.pinnedItems
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search clipboard history...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.background.secondary)

            Divider()

            // History list
            if filteredHistory.isEmpty && filteredPinned.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Clipboard History" : "No Results",
                    systemImage: searchText.isEmpty ? "clipboard" : "magnifyingglass",
                    description: Text(searchText.isEmpty ? "Copy something to see it here" : "Try a different search")
                )
            } else {
                List {
                    // Pinned section
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
                .onKeyPress(characters: CharacterSet(charactersIn: "jJ")) { _ in moveSelection(by: 1); return .handled }
                .onKeyPress(characters: CharacterSet(charactersIn: "kK")) { _ in moveSelection(by: -1); return .handled }
                .onKeyPress(.return) { pasteSelectedItem(); return .handled }
            }

            Divider()

            // Footer
            HStack {
                Text("\(clipboardManager.history.count) items")
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.85))

                Spacer()

                Button(action: { SettingsWindowController.open() }) {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
                .help("Settings")

                Button("Clear All") {
                    clipboardManager.clearHistory()
                }
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.85))
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
        guard selectedIndex >= 0 && selectedIndex < allItems.count else { return }
        let item = allItems[selectedIndex]
        clipboardManager.paste(item: item)
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isPinned: Bool
    let clipboardManager: ClipboardManager
    var shortcutHint: String? = nil
    var isSelected: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var accentColor: Color {
        isPinned
            ? .orange
            : Color(red: 0.0, green: 0.6, blue: 1.0)
    }

    private var cardBackground: Color {
        if isSelected {
            return colorScheme == .dark
                ? Color.accentColor.opacity(0.25)
                : Color.accentColor.opacity(0.15)
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.03)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Accent bar on left
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 3)

            HStack(alignment: .top, spacing: 8) {
                // Pin indicator
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                }

                // Content & metadata stacked
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.preview)
                        .lineLimit(2)
                        .font(.system(.callout, weight: .medium))
                        .foregroundStyle(.primary)

                    // Metadata line - fixed columns for alignment
                    HStack(spacing: 0) {
                        // Source app icon
                        if let icon = item.sourceAppIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 16, height: 16)
                                .help(item.sourceAppName ?? "Unknown app")
                                .padding(.trailing, 8)
                        }

                        Text(item.stats)
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.85))
                            .frame(minWidth: 75, alignment: .leading)

                        Text(item.timeAgo)
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.6))
                            .frame(minWidth: 28, alignment: .leading)

                        // Paste count badge
                        if item.pasteCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 9))
                                Text("\(item.pasteCount)")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.green.opacity(0.8))
                            .frame(minWidth: 30, alignment: .leading)
                            .help("Pasted \(item.pasteCount) time\(item.pasteCount == 1 ? "" : "s")")
                        }

                        if let hint = shortcutHint {
                            Spacer()
                            Text(hint)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.primary.opacity(0.55))
                        }
                    }
                    .lineLimit(1)
                }

                Spacer(minLength: 4)

                // Paste button - aligned with preview text
                Button(action: { clipboardManager.paste(item: item) }) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(accentColor)
                }
                .buttonStyle(PasteButtonStyle(accentColor: accentColor))
                .help("Copy & Paste")
                .padding(.top, 2)
            }
            .padding(.vertical, 10)
            .padding(.leading, 10)
            .padding(.trailing, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            clipboardManager.paste(item: item)
        }
        .contextMenu {
            Button("Paste") { clipboardManager.paste(item: item) }
            Divider()
            Button(isPinned ? "Unpin" : "Pin") {
                clipboardManager.togglePin(item: item)
            }
            Divider()
            Button("Delete", role: .destructive) { clipboardManager.delete(item: item) }
        }
    }
}

// MARK: - Paste Button Style with Dramatic Press Feedback

struct PasteButtonStyle: ButtonStyle {
    let accentColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(6)
            .background(
                Circle()
                    .fill(configuration.isPressed ? accentColor : accentColor.opacity(0.15))
            )
            .foregroundStyle(configuration.isPressed ? .white : accentColor)
            .scaleEffect(configuration.isPressed ? 0.75 : 1.0)
            .shadow(color: configuration.isPressed ? accentColor.opacity(0.6) : .clear, radius: 8)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
