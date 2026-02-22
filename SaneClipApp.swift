import AppKit
import KeyboardShortcuts
import SwiftUI
#if !APP_STORE
    import Sparkle
#endif
import LocalAuthentication
import os.log

private let appLogger = Logger(subsystem: "com.saneclip.app", category: "App")

#if !APP_STORE

    // MARK: - Update Service

    @MainActor
    class UpdateService: NSObject, ObservableObject {
        static let shared = UpdateService()

        private var updaterController: SPUStandardUpdaterController?

        override init() {
            super.init()
            updaterController = SPUStandardUpdaterController(
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
#endif

// MARK: - Keyboard Shortcuts Extension

extension KeyboardShortcuts.Name {
    static let showClipboardHistory = Self("showClipboardHistory", default: .init(.v, modifiers: [.command, .shift]))
    static let pasteAsPlainText = Self("pasteAsPlainText", default: .init(.v, modifiers: [.command, .shift, .option]))
    static let pasteFromStack = Self("pasteFromStack", default: .init(.v, modifiers: [.command, .control]))
    static let pasteSmartMode = Self("pasteSmartMode", default: .init(.v, modifiers: [.command, .shift, .control]))
    // Quick paste shortcuts for items 1-9
    static let pasteItem1 = Self("pasteItem1", default: .init(.one, modifiers: [.command, .control]))
    static let pasteItem2 = Self("pasteItem2", default: .init(.two, modifiers: [.command, .control]))
    static let pasteItem3 = Self("pasteItem3", default: .init(.three, modifiers: [.command, .control]))
    static let pasteItem4 = Self("pasteItem4", default: .init(.four, modifiers: [.command, .control]))
    static let pasteItem5 = Self("pasteItem5", default: .init(.five, modifiers: [.command, .control]))
    static let pasteItem6 = Self("pasteItem6", default: .init(.six, modifiers: [.command, .control]))
    static let pasteItem7 = Self("pasteItem7", default: .init(.seven, modifiers: [.command, .control]))
    static let pasteItem8 = Self("pasteItem8", default: .init(.eight, modifiers: [.command, .control]))
    static let pasteItem9 = Self("pasteItem9", default: .init(.nine, modifiers: [.command, .control]))
}

// MARK: - AppDelegate

@MainActor
class SaneClipAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var clipboardManager: ClipboardManager!
    #if !APP_STORE
        private var updateService: UpdateService!
    #endif
    private var onboardingWindow: NSWindow?
    /// Track when user last authenticated with Touch ID (grace period)
    private var lastAuthenticationTime: Date?
    private let authGracePeriod: TimeInterval = 30.0 // seconds - stays unlocked for 30s

    deinit {
        NotificationCenter.default.removeObserver(self, name: .menuBarIconChanged, object: nil)
    }

    func applicationDidFinishLaunching(_: Notification) {
        appLogger.info("SaneClip starting...")
        NSApp.appearance = NSAppearance(named: .darkAqua)

        #if !DEBUG && !APP_STORE
            SaneAppMover.moveToApplicationsFolderIfNeeded()
        #endif

        #if !APP_STORE
            // Initialize update service (Sparkle)
            updateService = UpdateService.shared
        #endif

        // Apply dock visibility setting (must happen early)
        _ = SettingsModel.shared

        // Initialize clipboard manager
        clipboardManager = ClipboardManager()
        ClipboardManager.shared = clipboardManager

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
            self,
            selector: #selector(handleMenuBarIconChanged(_:)),
            name: .menuBarIconChanged,
            object: nil
        )

        // Dismiss popover when paste is about to simulate Cmd+V
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDismissForPaste),
            name: .dismissForPaste,
            object: nil
        )

        // Register as macOS Services provider (right-click → Services → "Save to SaneClip")
        #if !APP_STORE
            NSApp.servicesProvider = self
            NSApp.registerServicesMenuSendTypes([.string], returnTypes: [])
        #endif

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ClipboardHistoryView(clipboardManager: clipboardManager)
                .preferredColorScheme(.dark)
        )

        // Set up keyboard shortcuts
        setupKeyboardShortcuts()

        appLogger.info("SaneClip ready")

        // Show onboarding on first launch (delay to ensure app is fully ready)
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showOnboarding()
            }
        }
    }

    private func showOnboarding() {
        let onboardingView = OnboardingView()
            .preferredColorScheme(.dark)
        let hostingController = NSHostingController(rootView: onboardingView)

        onboardingWindow = NSWindow(contentViewController: hostingController)
        onboardingWindow?.title = "Welcome to SaneClip"
        onboardingWindow?.appearance = NSAppearance(named: .darkAqua)
        onboardingWindow?.styleMask = [.titled, .closable]
        onboardingWindow?.setContentSize(NSSize(width: 700, height: 480))
        onboardingWindow?.center()
        onboardingWindow?.isReleasedWhenClosed = false

        onboardingWindow?.makeKeyAndOrderFront(nil)
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

        KeyboardShortcuts.onKeyUp(for: .pasteFromStack) { [weak self] in
            Task { @MainActor in
                self?.clipboardManager.pasteFromStack()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .pasteSmartMode) { [weak self] in
            Task { @MainActor in
                guard let item = self?.clipboardManager.history.first else { return }
                self?.clipboardManager.pasteSmartMode(item: item)
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

        // Paste from stack: Cmd+Ctrl+V
        if KeyboardShortcuts.getShortcut(for: .pasteFromStack) == nil {
            KeyboardShortcuts.setShortcut(.init(.v, modifiers: [.command, .control]), for: .pasteFromStack)
            appLogger.info("Set default shortcut: Cmd+Ctrl+V for paste from stack")
        }

        // Smart paste: Cmd+Shift+Ctrl+V
        if KeyboardShortcuts.getShortcut(for: .pasteSmartMode) == nil {
            KeyboardShortcuts.setShortcut(.init(.v, modifiers: [.command, .shift, .control]), for: .pasteSmartMode)
            appLogger.info("Set default shortcut: Cmd+Shift+Ctrl+V for smart paste")
        }

        // Quick paste shortcuts: Cmd+Ctrl+1 through 9
        let keys: [KeyboardShortcuts.Key] = [.one, .two, .three, .four, .five, .six, .seven, .eight, .nine]
        let shortcuts: [KeyboardShortcuts.Name] = [
            .pasteItem1, .pasteItem2, .pasteItem3, .pasteItem4, .pasteItem5,
            .pasteItem6, .pasteItem7, .pasteItem8, .pasteItem9
        ]
        for (key, shortcut) in zip(keys, shortcuts) where KeyboardShortcuts.getShortcut(for: shortcut) == nil {
            KeyboardShortcuts.setShortcut(.init(key, modifiers: [.command, .control]), for: shortcut)
        }
    }

    @objc private func clearHistoryFromMenu() {
        clipboardManager.clearHistory()
    }

    @objc private func openSettings() {
        SettingsWindowController.open()
    }

    // MARK: - Biometric Authentication

    private func authenticateWithBiometrics(completion: @escaping @Sendable (Bool) -> Void) {
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
        guard statusItem.button != nil else { return }

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
                        guard success else { return }
                        Task { @MainActor in
                            self?.lastAuthenticationTime = Date()
                            // Small delay to let Touch ID dialog fully dismiss
                            try? await Task.sleep(nanoseconds: 150_000_000)
                            self?.showPopoverAtButton()
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

        let showItem = NSMenuItem(title: "Show History", action: #selector(showPopover), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        menu.addItem(NSMenuItem.separator())

        addRecentItemsToMenu(menu)
        menu.addItem(buildSnippetsSubmenu())
        menu.addItem(NSMenuItem.separator())

        let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearHistoryFromMenu), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(
            title: "Quit SaneClip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
        )
        menu.addItem(quit)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
    }

    // MARK: - Shared Menu Helpers

    private func addRecentItemsToMenu(_ menu: NSMenu) {
        let recentItems = Array(clipboardManager.history.prefix(5))
        guard !recentItems.isEmpty else { return }
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

    private func buildSnippetsSubmenu() -> NSMenuItem {
        let snippetsMenu = NSMenu()
        let snippetsItem = NSMenuItem(title: "Snippets", action: nil, keyEquivalent: "")
        let recentSnippets = Array(SnippetManager.shared.snippets.prefix(10))
        if !recentSnippets.isEmpty {
            for (index, snippet) in recentSnippets.enumerated() {
                let snippetMenuItem = NSMenuItem(
                    title: snippet.name,
                    action: #selector(pasteSnippetFromMenu(_:)),
                    keyEquivalent: ""
                )
                snippetMenuItem.tag = index
                snippetMenuItem.target = self
                snippetsMenu.addItem(snippetMenuItem)
            }
        } else {
            let emptyItem = NSMenuItem(title: "No snippets", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            snippetsMenu.addItem(emptyItem)
        }
        snippetsItem.submenu = snippetsMenu
        return snippetsItem
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
                    guard success else { return }
                    Task { @MainActor in
                        self?.lastAuthenticationTime = Date()
                        // Small delay to let Touch ID dialog fully dismiss
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        self?.showPopoverAtButton()
                    }
                }
            }
        } else {
            showPopoverAtButton()
        }
    }

    @objc private func pasteFromMenu(_ sender: NSMenuItem) {
        let index = sender.tag
        guard index < clipboardManager.history.count else { return }

        if SettingsModel.shared.requireTouchID {
            if let lastAuth = lastAuthenticationTime,
               Date().timeIntervalSince(lastAuth) < authGracePeriod {
                clipboardManager.pasteItemAt(index: index)
            } else {
                authenticateWithBiometrics { [weak self] success in
                    guard success else { return }
                    Task { @MainActor in
                        self?.lastAuthenticationTime = Date()
                        self?.clipboardManager.pasteItemAt(index: index)
                    }
                }
            }
        } else {
            clipboardManager.pasteItemAt(index: index)
        }
    }

    @objc private func pasteSnippetFromMenu(_ sender: NSMenuItem) {
        let index = sender.tag
        let snippets = SnippetManager.shared.snippets
        guard index < snippets.count else { return }
        let snippet = snippets[index]

        if SettingsModel.shared.requireTouchID {
            if let lastAuth = lastAuthenticationTime,
               Date().timeIntervalSince(lastAuth) < authGracePeriod {
                clipboardManager.pasteSnippet(snippet)
            } else {
                authenticateWithBiometrics { [weak self] success in
                    guard success else { return }
                    Task { @MainActor in
                        self?.lastAuthenticationTime = Date()
                        self?.clipboardManager.pasteSnippet(snippet)
                    }
                }
            }
        } else {
            clipboardManager.pasteSnippet(snippet)
        }
    }

    @objc private func handleMenuBarIconChanged(_ notification: Notification) {
        guard let iconName = notification.object as? String,
              let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "SaneClip")
    }

    @objc private func handleDismissForPaste() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    // MARK: - URL Scheme Handling

    func application(_: NSApplication, open urls: [URL]) {
        for url in urls {
            URLSchemeHandler.shared.handle(url)
        }
    }

    // MARK: - Dock Menu

    func applicationDockMenu(_: NSApplication) -> NSMenu? {
        let menu = NSMenu()

        // Show History
        let showHistoryItem = NSMenuItem(title: "Show History", action: #selector(showPopover), keyEquivalent: "")
        showHistoryItem.target = self
        menu.addItem(showHistoryItem)

        menu.addItem(NSMenuItem.separator())

        // Recent items & snippets
        addRecentItemsToMenu(menu)
        menu.addItem(buildSnippetsSubmenu())

        menu.addItem(NSMenuItem.separator())

        // Clear History
        let clearHistoryItem = NSMenuItem(title: "Clear History", action: #selector(clearHistoryFromMenu), keyEquivalent: "")
        clearHistoryItem.target = self
        menu.addItem(clearHistoryItem)

        menu.addItem(NSMenuItem.separator())

        #if !APP_STORE
            // Check for Updates
            let updatesItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
            updatesItem.target = self
            menu.addItem(updatesItem)
        #endif

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        return menu
    }

    #if !APP_STORE
        @objc private func checkForUpdates() {
            updateService.checkForUpdates()
        }
    #endif

    // MARK: - macOS Services

    @objc func saveToSaneClip(
        _ pboard: NSPasteboard,
        userData _: String?,
        error errorPointer: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let text = pboard.string(forType: .string), !text.isEmpty else {
            errorPointer.pointee = "No text found on pasteboard" as NSString
            return
        }

        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let bundleID = frontmostApp?.bundleIdentifier
        let appName = frontmostApp?.localizedName

        // Respect excluded apps
        if let bundleID, SettingsModel.shared.isAppExcluded(bundleID) {
            return
        }

        let item = ClipboardItem(
            content: .text(text),
            sourceAppBundleID: bundleID,
            sourceAppName: appName
        )
        clipboardManager.addItemFromService(item)

        SettingsModel.shared.pasteSound.play()
    }
}
