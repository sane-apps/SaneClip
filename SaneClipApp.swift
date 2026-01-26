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
    static let pasteFromStack = Self("pasteFromStack")
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
    private var onboardingWindow: NSWindow?
    nonisolated(unsafe) private var menuBarIconObserver: NSObjectProtocol?

    /// Track when user last authenticated with Touch ID (grace period)
    private var lastAuthenticationTime: Date?
    private let authGracePeriod: TimeInterval = 30.0  // seconds - stays unlocked for 30s

    deinit {
        if let observer = menuBarIconObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        appLogger.info("SaneClip starting...")

        // Initialize update service (Sparkle)
        updateService = UpdateService.shared

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
        menuBarIconObserver = NotificationCenter.default.addObserver(
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

        let showHistoryItem = NSMenuItem(title: "Show History", action: #selector(togglePopover), keyEquivalent: "")
        showHistoryItem.target = self
        menu.addItem(showHistoryItem)

        menu.addItem(NSMenuItem.separator())

        let clearHistoryItem = NSMenuItem(title: "Clear History", action: #selector(clearHistoryFromMenu), keyEquivalent: "")
        clearHistoryItem.target = self
        menu.addItem(clearHistoryItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit SaneClip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
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

        // Show onboarding on first launch (delay to ensure app is fully ready)
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showOnboarding()
            }
        }
    }

    private func showOnboarding() {
        let onboardingView = OnboardingView()
        let hostingController = NSHostingController(rootView: onboardingView)

        onboardingWindow = NSWindow(contentViewController: hostingController)
        onboardingWindow?.title = "Welcome to SaneClip"
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

        let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearHistoryFromMenu), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(
            title: "Quit SaneClip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

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
