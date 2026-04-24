import AppKit
import KeyboardShortcuts
import SaneUI
import SwiftUI
#if !APP_STORE
@preconcurrency import ApplicationServices
#endif
import LocalAuthentication
import os.log

private let appLogger = Logger(subsystem: "com.saneclip.app", category: "App")

@MainActor
private func menuBarTemplateImage(named systemName: String) -> NSImage? {
    let image = NSImage(systemSymbolName: systemName, accessibilityDescription: "SaneClip")
    image?.isTemplate = true
    return image
}

extension KeyboardShortcuts.Name {
    static let showClipboardHistory = Self("showClipboardHistory")
    static let pasteAsPlainText = Self("pasteAsPlainText")
    static let pasteFromStack = Self("pasteFromStack")
    static let pasteSmartMode = Self("pasteSmartMode")
    static let ignoreNextCopy = Self("ignoreNextCopy")
    static let captureScreenshot = Self("captureScreenshot")
    static let captureText = Self("captureText")
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
    var clipboardManager: ClipboardManager!
    let screenCaptureService = ScreenCaptureService()
    let captureOCRService = CaptureOCRService()
    #if !APP_STORE && !SETAPP
    private var updateService: UpdateService!
    #endif
    /// Track when user last authenticated with Touch ID (grace period)
    private var lastAuthenticationTime: Date?
    private let authGracePeriod: TimeInterval = 30.0 // seconds - stays unlocked for 30s

    // MARK: - License

    #if APP_STORE
    let licenseService = LicenseService(
        appName: "SaneClip",
        purchaseBackend: .appStore(productID: "com.saneclip.app.pro.unlock")
    )
    #elseif SETAPP
    let licenseService = LicenseService(
        appName: "SaneClip",
        purchaseBackend: .setapp
    )
    #else
    let licenseService = LicenseService(
        appName: "SaneClip",
        checkoutURL: LicenseService.directCheckoutURL(appSlug: "saneclip")
    )
    #endif

    private let hasSeenWelcomeKey = "hasSeenWelcome"
    private let welcomeResumePageKey = "welcomeResumePage"
    private let permissionsWelcomePage = 5
    private var requiresHistoryAuth: Bool {
        licenseService.isPro && SettingsModel.shared.requireTouchID
    }

    private var hasSeenWelcome: Bool {
        get { UserDefaults.standard.bool(forKey: hasSeenWelcomeKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasSeenWelcomeKey) }
    }

    private var welcomeResumePage: Int {
        get { UserDefaults.standard.object(forKey: welcomeResumePageKey) as? Int ?? 0 }
        set { UserDefaults.standard.set(newValue, forKey: welcomeResumePageKey) }
    }

    private func clearWelcomeResumePage() {
        UserDefaults.standard.removeObject(forKey: welcomeResumePageKey)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .menuBarIconChanged, object: nil)
    }

    func applicationDidFinishLaunching(_: Notification) {
        appLogger.info("SaneClip starting...")
        NSApp.appearance = NSAppearance(named: .darkAqua)

        #if !DEBUG && !APP_STORE && !SETAPP
        if SaneAppMover.moveToApplicationsFolderIfNeeded(prompt: .init(
            messageText: "Move to Applications?",
            informativeText: "{appName} works best from your Applications folder. Move it there now? You may be asked for your password.",
            moveButtonTitle: "Move to Applications",
            cancelButtonTitle: "Not Now"
        )) { return }
        #endif

        #if !APP_STORE && !SETAPP
        if let testFeedOverride = UpdateService.testFeedOverride() {
            UserDefaults.standard.set(testFeedOverride, forKey: "SUFeedURL")
            appLogger.info("Using test Sparkle feed override: \(testFeedOverride, privacy: .public)")
        }

        // Initialize update service (Sparkle)
        if UpdateService.shouldInitialize() {
            updateService = UpdateService.shared
        } else {
            appLogger.info("Skipping Sparkle updater during XCTest host run")
        }

        if UpdateService.shouldAutoCheckOnLaunch() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.updateService?.checkForUpdates()
            }
        }
        #endif

        // Freemium: always allow app to start — no hard gate
        licenseService.checkCachedLicense()
        setupApp()
        initializeSyncOnLaunch()
        SetappIntegration.logPurchaseType()
        if hasSeenWelcome {
            clearWelcomeResumePage()
            SetappIntegration.showReleaseNotesIfNeeded()
        }

        // Fire launch event (capture isPro on main actor before detaching)
        let launchIsPro = licenseService.isPro
        let isFirstLaunch = !hasSeenWelcome
        if SaneBackgroundAppDefaults.launchAtLogin {
            _ = SaneLoginItemPolicy.enableByDefaultIfNeeded(isFirstLaunch: isFirstLaunch)
        }
        Task.detached {
            await EventTracker.log(launchIsPro ? "app_launch_pro" : "app_launch_free", app: "saneclip")
            if isFirstLaunch, !launchIsPro {
                await EventTracker.log("new_free_user", app: "saneclip")
            }
        }

        // Show welcome screen on first install (menu bar apps need standalone window)
        if !hasSeenWelcome {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.showWelcomeWindow()
            }
        }
    }

    nonisolated static func shouldInitializeSyncOnLaunch(
        hasClipboardManager: Bool,
        syncFeatureCompiled: Bool
    ) -> Bool {
        hasClipboardManager && syncFeatureCompiled
    }

    private func initializeSyncOnLaunch() {
        #if ENABLE_SYNC
        guard Self.shouldInitializeSyncOnLaunch(
            hasClipboardManager: ClipboardManager.shared != nil,
            syncFeatureCompiled: true
        ) else { return }
        _ = SyncCoordinator.shared
        #endif
    }

    private func showWelcomeWindow() {
        let onboardingBasicFeatures: [(icon: String, text: String)] = [
            ("clipboard", "Clipboard history — last 50 items"),
            ("magnifyingglass", "Search, source-aware filtering, and pinning"),
            ("cursorarrow.motionlines", "Open history at the menu bar icon or mouse cursor"),
            ("camera.viewfinder", "Capture Screenshot saves images into history"),
            ("iphone", "Free iPhone & iPad companion app with optional private iCloud sync"),
            ("lock.shield", "On-device privacy defaults and excluded apps")
        ]

        let onboardingProFeatures: [(icon: String, text: String)] = [
            ("checkmark", "Everything in Basic, plus:"),
            ("infinity", "Unlimited clipboard history"),
            ("textformat.alt", "Paste as plain text, Smart Paste, and text transforms"),
            ("text.viewfinder", "OCR Capture for text grabs and searchable screenshot sidecars"),
            ("square.stack.3d.up", "Paste Stack for forms and structured workflows"),
            ("text.quote", "Snippets with placeholders"),
            ("tag.fill", "Titles, tags, collections, and item notes"),
            ("ruler", "Clipboard Rules to auto-clean what you copy"),
            ("touchid", "Touch ID history lock and history encryption"),
            ("arrow.up.arrow.down.circle", "Export / import history")
        ]

        WelcomeWindow.show(
            appName: "SaneClip",
            appIcon: "list.clipboard.fill",
            freeFeatures: onboardingBasicFeatures,
            proFeatures: onboardingProFeatures,
            permissionConfig: welcomePermissionConfig(),
            licenseService: licenseService,
            initialPage: welcomeResumePage,
            onPageChange: { [weak self] page in
                self?.welcomeResumePage = page
            },
            onDismiss: { [weak self] in
                self?.clearWelcomeResumePage()
                self?.hasSeenWelcome = true
                SetappIntegration.showReleaseNotesIfNeeded(delay: 0.2)
            }
        )
    }

    private var captureTextMenuItemTitle: String {
        licenseService.isPro ? CaptureWorkflow.text.menuTitle : "Capture Text Pro 🔒"
    }

    private func requestAccessibilityAccess() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) || AXIsProcessTrusted() {
            return
        }

        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    private func requestScreenRecordingAccess() {
        welcomeResumePage = permissionsWelcomePage

        if ScreenCapturePermissionService.isGranted() {
            return
        }

        if !ScreenCapturePermissionService.requestAccess() {
            ScreenCapturePermissionService.openSettings()
        }
    }

    private func welcomePermissionConfig() -> WelcomeGatePermissionConfig {
        #if APP_STORE
        return WelcomeGatePermissionConfig(
            title: "Grant Access",
            sections: [
                .init(
                    title: "Screen Recording",
                    bullets: [
                        ("text.viewfinder", "Capture Screenshot and Pro OCR capture need Screen Recording."),
                        ("lock.shield.fill", "macOS should prompt right away or open the correct Settings pane."),
                        ("arrow.clockwise", "After granting it, quit and reopen SaneClip once before testing capture.")
                    ],
                    grantedMessage: "Screen Recording is enabled. If capture still fails, quit and reopen SaneClip once.",
                    actionLabel: "Request Screen Recording",
                    actionHint: "If macOS does not finish the request inline, SaneClip will open the right Settings pane.",
                    initiallyGranted: ScreenCapturePermissionService.isGranted(),
                    refreshGranted: { ScreenCapturePermissionService.isGranted() },
                    action: {
                        self.requestScreenRecordingAccess()
                    }
                )
            ]
        )
        #else
        return WelcomeGatePermissionConfig(
            title: "Grant Access",
            sections: [
                .init(
                    title: "Accessibility",
                    bullets: [
                        ("cursorarrow.click.2", "Accessibility enables one-click paste and keyboard workflows."),
                        ("checkmark.circle", "Click once and macOS should request SaneClip directly."),
                        ("hand.tap.fill", "You only need this if you want SaneClip to paste for you.")
                    ],
                    grantedMessage: "Accessibility is enabled. One-click paste is ready.",
                    actionLabel: "Request Accessibility Access",
                    actionHint: "If macOS does not finish the request inline, SaneClip will open the right Settings pane.",
                    initiallyGranted: AXIsProcessTrusted(),
                    refreshGranted: { AXIsProcessTrusted() },
                    action: {
                        self.requestAccessibilityAccess()
                    }
                ),
                .init(
                    title: "Screen Recording",
                    bullets: [
                        ("text.viewfinder", "Capture Screenshot and Pro OCR capture need Screen Recording."),
                        ("lock.shield.fill", "macOS should prompt right away or open the correct Settings pane."),
                        ("arrow.clockwise", "After granting it, quit and reopen SaneClip once before testing capture.")
                    ],
                    grantedMessage: "Screen Recording is enabled. If capture still fails, quit and reopen SaneClip once.",
                    actionLabel: "Request Screen Recording",
                    actionHint: "If macOS does not finish the request inline, SaneClip will open the right Settings pane.",
                    initiallyGranted: ScreenCapturePermissionService.isGranted(),
                    refreshGranted: { ScreenCapturePermissionService.isGranted() },
                    action: {
                        self.requestScreenRecordingAccess()
                    }
                )
            ]
        )
        #endif
    }

    private func setupApp() {
        // Make license service available to settings
        let appLicenseService = licenseService
        SettingsWindowController.licenseService = appLicenseService
        let appLicenseIsPro = appLicenseService.isPro
        appLogger.info("Settings license service seeded with isPro=\(appLicenseIsPro)")

        // Apply dock visibility setting (must happen early)
        _ = SettingsModel.shared

        // Initialize clipboard manager and wire license service for Pro gating
        clipboardManager = ClipboardManager()
        clipboardManager.licenseService = appLicenseService
        ClipboardManager.shared = clipboardManager

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Use SF Symbol from settings
            let iconName = SettingsModel.shared.menuBarIcon
            button.image = menuBarTemplateImage(named: iconName)
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReopenHistoryAfterPaste),
            name: .reopenHistoryAfterPaste,
            object: nil
        )

        // Register as macOS Services provider (right-click → Services → "Save to SaneClip")
        #if !APP_STORE
        NSApp.servicesProvider = self
        NSApp.registerServicesMenuSendTypes([.string], returnTypes: [])
        #endif

        // Create popover — pass licenseService so history view can check Pro status
        popover = NSPopover()
        resetHistoryPopoverSize()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ClipboardHistoryView(clipboardManager: clipboardManager, licenseService: licenseService)
                .frame(
                    minWidth: ClipboardHistoryView.popoverWidth,
                    idealWidth: ClipboardHistoryView.popoverWidth,
                    maxWidth: ClipboardHistoryView.popoverWidth,
                    minHeight: ClipboardHistoryView.popoverMinHeight,
                    idealHeight: ClipboardHistoryView.popoverMinHeight,
                    alignment: .top
                )
                .preferredColorScheme(.dark)
        )

        installMainMenu()

        // Set up keyboard shortcuts
        setupKeyboardShortcuts()

        appLogger.info("SaneClip ready")
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

        KeyboardShortcuts.onKeyUp(for: .ignoreNextCopy) { [weak self] in
            Task { @MainActor in
                self?.clipboardManager.ignoreNextCopy()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .captureScreenshot) { [weak self] in
            Task { @MainActor in
                await self?.runCaptureWorkflow(.screenshot)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .captureText) { [weak self] in
            Task { @MainActor in
                await self?.runCaptureWorkflow(.text)
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
        clearLegacyProShortcutDefaultsForBasicUsers()

        // Show clipboard history: Cmd+Shift+V
        if KeyboardShortcuts.getShortcut(for: .showClipboardHistory) == nil {
            KeyboardShortcuts.setShortcut(.init(.v, modifiers: [.command, .shift]), for: .showClipboardHistory)
            appLogger.info("Set default shortcut: Cmd+Shift+V for clipboard history")
        }

        // Pro-only defaults should not be assigned for Basic users.
        if licenseService.isPro {
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
        }

        if KeyboardShortcuts.getShortcut(for: .ignoreNextCopy) == nil {
            KeyboardShortcuts.setShortcut(.init(.i, modifiers: [.command, .shift, .control]), for: .ignoreNextCopy)
            appLogger.info("Set default shortcut: Cmd+Shift+Ctrl+I for ignore next copy")
        }

        if KeyboardShortcuts.getShortcut(for: .captureScreenshot) == nil {
            KeyboardShortcuts.setShortcut(.init(.s, modifiers: [.command, .shift, .control]), for: .captureScreenshot)
            appLogger.info("Set default shortcut: Cmd+Shift+Ctrl+S for capture screenshot")
        }

        if licenseService.isPro, KeyboardShortcuts.getShortcut(for: .captureText) == nil {
            KeyboardShortcuts.setShortcut(.init(.t, modifiers: [.command, .shift, .control]), for: .captureText)
            appLogger.info("Set default shortcut: Cmd+Shift+Ctrl+T for capture text")
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

    /// Migration cleanup: old builds auto-assigned Pro shortcuts even for Basic users.
    /// Remove only those legacy defaults (preserves intentional custom mappings).
    private func clearLegacyProShortcutDefaultsForBasicUsers() {
        guard !licenseService.isPro else { return }

        let legacyDefaults: [(name: KeyboardShortcuts.Name, shortcut: KeyboardShortcuts.Shortcut)] = [
            (.pasteAsPlainText, .init(.v, modifiers: [.command, .shift, .option])),
            (.pasteFromStack, .init(.v, modifiers: [.command, .control])),
            (.pasteSmartMode, .init(.v, modifiers: [.command, .shift, .control])),
            (.captureText, .init(.t, modifiers: [.command, .shift, .control]))
        ]

        for legacy in legacyDefaults
        where KeyboardShortcuts.getShortcut(for: legacy.name) == legacy.shortcut {
            KeyboardShortcuts.reset(legacy.name)
            appLogger.info("Cleared legacy Pro shortcut for Basic user")
        }
    }

    @objc private func clearHistoryFromMenu() {
        clipboardManager.clearHistory()
    }

    @objc private func openSettings() {
        SettingsWindowController.open()
    }

    @objc private func showReleaseNotes() {
        SetappIntegration.showReleaseNotes()
    }

    @objc private func openGeneralSettings() {
        SettingsWindowController.open(tab: .general)
    }

    @objc private func openShortcutsSettings() {
        SettingsWindowController.open(tab: .shortcuts)
    }

    @objc private func openSnippetsSettings() {
        SettingsWindowController.open(tab: .snippets)
    }

    #if ENABLE_SYNC
    @objc private func openSyncSettings() {
        SettingsWindowController.open(tab: .sync)
    }
    #endif

    @objc private func openStorageSettings() {
        SettingsWindowController.open(tab: .storage)
    }

    @objc private func openLicenseSettings() {
        SettingsWindowController.open(tab: .license)
    }

    @objc private func openAboutSettings() {
        SettingsWindowController.open(tab: .about)
    }

    @objc private func requestExcludedAppPicker() {
        appLogger.info("Settings command requested excluded app picker")
        SettingsWindowController.schedulePendingAction(.excludedAppPicker)
        SettingsWindowController.open(tab: .general)
        NotificationCenter.default.post(name: .settingsAddExcludedAppRequested, object: nil)
    }

    @objc private func focusHistorySearch() {
        if !popover.isShown {
            showHistoryPopover()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .historySearchShortcutRequested, object: nil)
        }
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
        SetappIntegration.reportMenuBarInteraction()

        // Check if right-click
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showContextMenu()
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Check if Touch ID is required
            if requiresHistoryAuth {
                // Check if within grace period
                if let lastAuth = lastAuthenticationTime,
                   Date().timeIntervalSince(lastAuth) < authGracePeriod {
                    // Within grace period, no auth needed
                    showHistoryPopover()
                } else {
                    authenticateWithBiometrics { [weak self] success in
                        guard success else { return }
                        Task { @MainActor in
                            self?.lastAuthenticationTime = Date()
                            // Small delay to let Touch ID dialog fully dismiss
                            try? await Task.sleep(nanoseconds: 150_000_000)
                            self?.showHistoryPopover()
                        }
                    }
                }
            } else {
                showHistoryPopover()
            }
        }
    }

    private func showPopoverAtButton() {
        guard let button = statusItem.button else { return }
        resetHistoryPopoverSize()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        if let popoverWindow = popover.contentViewController?.view.window {
            popoverWindow.makeKey()
        }
    }

    private func showPopoverAtCursor() {
        guard let button = statusItem.button else { return }
        resetHistoryPopoverSize()

        // Use the status item as an anchor view, then reposition to cursor.
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        guard let popoverWindow = popover.contentViewController?.view.window else { return }

        let mouse = NSEvent.mouseLocation
        let size = popoverWindow.frame.size
        let targetScreen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        let visible = targetScreen?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero

        // Prefer below cursor; fall back above if needed.
        var origin = NSPoint(
            x: mouse.x - (size.width / 2.0),
            y: mouse.y - size.height - 12
        )
        if origin.y < visible.minY {
            origin.y = mouse.y + 16
        }

        let minX = visible.minX
        let maxX = max(visible.minX, visible.maxX - size.width)
        let minY = visible.minY
        let maxY = max(visible.minY, visible.maxY - size.height)
        origin.x = min(max(origin.x, minX), maxX)
        origin.y = min(max(origin.y, minY), maxY)

        popoverWindow.setFrameOrigin(origin)
        popoverWindow.makeKey()
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "SaneClip")
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        appMenu.addItem(settingsItem)

        #if SETAPP
        let whatsNewItem = NSMenuItem(title: "What's New...", action: #selector(showReleaseNotes), keyEquivalent: "")
        whatsNewItem.target = self
        appMenu.addItem(whatsNewItem)
        #endif

        appMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit SaneClip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)

        let editMenu = NSMenu(title: "Edit")
        let captureScreenshotItem = NSMenuItem(
            title: CaptureWorkflow.screenshot.menuTitle,
            action: #selector(captureScreenshotFromMenu),
            keyEquivalent: ""
        )
        captureScreenshotItem.target = self
        editMenu.addItem(captureScreenshotItem)

        let captureTextItem = NSMenuItem(
            title: captureTextMenuItemTitle,
            action: #selector(captureTextFromMenu),
            keyEquivalent: ""
        )
        captureTextItem.target = self
        editMenu.addItem(captureTextItem)

        editMenu.addItem(NSMenuItem.separator())

        let searchHistoryItem = NSMenuItem(title: "Search History", action: #selector(focusHistorySearch), keyEquivalent: "f")
        searchHistoryItem.keyEquivalentModifierMask = [.command]
        searchHistoryItem.target = self
        editMenu.addItem(searchHistoryItem)

        let addExcludedAppItem = NSMenuItem(title: "Add Excluded App...", action: #selector(requestExcludedAppPicker), keyEquivalent: "n")
        addExcludedAppItem.keyEquivalentModifierMask = [.command]
        addExcludedAppItem.target = self
        editMenu.addItem(addExcludedAppItem)
        editMenuItem.submenu = editMenu

        let settingsMenuItem = NSMenuItem()
        mainMenu.addItem(settingsMenuItem)

        let settingsMenu = NSMenu(title: "Settings")
        for item in settingsMenuItems() {
            settingsMenu.addItem(item)
        }
        settingsMenuItem.submenu = settingsMenu

        NSApp.mainMenu = mainMenu
    }

    private func settingsMenuItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = [
            settingsMenuItem(title: "General", action: #selector(openGeneralSettings), key: "1"),
            settingsMenuItem(title: "Shortcuts", action: #selector(openShortcutsSettings), key: "2")
        ]

        #if ENABLE_SYNC
        items.append(settingsMenuItem(title: "Sync", action: #selector(openSyncSettings), key: "3"))
        items.append(settingsMenuItem(title: "Snippets", action: #selector(openSnippetsSettings), key: "4"))
        items.append(settingsMenuItem(title: "Storage", action: #selector(openStorageSettings), key: "5"))
        items.append(settingsMenuItem(title: "License", action: #selector(openLicenseSettings), key: "6"))
        items.append(settingsMenuItem(title: "About", action: #selector(openAboutSettings), key: "7"))
        #else
        items.append(settingsMenuItem(title: "Snippets", action: #selector(openSnippetsSettings), key: "3"))
        items.append(settingsMenuItem(title: "Storage", action: #selector(openStorageSettings), key: "4"))
        items.append(settingsMenuItem(title: "License", action: #selector(openLicenseSettings), key: "5"))
        items.append(settingsMenuItem(title: "About", action: #selector(openAboutSettings), key: "6"))
        #endif

        return items
    }

    private func settingsMenuItem(title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = [.command]
        item.target = self
        return item
    }

    private func showHistoryPopover() {
        if SettingsModel.shared.openHistoryAtCursor {
            showPopoverAtCursor()
        } else {
            showPopoverAtButton()
        }
    }

    private func resetHistoryPopoverSize() {
        let size = NSSize(
            width: ClipboardHistoryView.popoverWidth,
            height: ClipboardHistoryView.popoverMinHeight
        )
        popover.contentSize = size
        popover.contentViewController?.preferredContentSize = size
    }

    private func showContextMenu() {
        guard let button = statusItem.button else { return }

        let menu = NSMenu()

        let captureScreenshotItem = NSMenuItem(
            title: CaptureWorkflow.screenshot.menuTitle,
            action: #selector(captureScreenshotFromMenu),
            keyEquivalent: ""
        )
        captureScreenshotItem.target = self
        menu.addItem(captureScreenshotItem)

        let captureTextItem = NSMenuItem(
            title: captureTextMenuItemTitle,
            action: #selector(captureTextFromMenu),
            keyEquivalent: ""
        )
        captureTextItem.target = self
        menu.addItem(captureTextItem)

        menu.addItem(NSMenuItem.separator())

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

        #if SETAPP
        let whatsNewItem = NSMenuItem(title: "What's New...", action: #selector(showReleaseNotes), keyEquivalent: "")
        whatsNewItem.target = self
        menu.addItem(whatsNewItem)
        #endif

        #if !APP_STORE && !SETAPP
        let updatesItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
        updatesItem.target = self
        menu.addItem(updatesItem)
        #endif

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
        guard licenseService.isPro else {
            let snippetsItem = NSMenuItem(title: "Snippets Pro \u{1F512}", action: #selector(showSnippetsUpsell), keyEquivalent: "")
            snippetsItem.target = self
            return snippetsItem
        }

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

    @objc private func showSnippetsUpsell() {
        ProUpsellWindow.show(feature: ProFeature.snippets, licenseService: licenseService)
    }

    @objc private func showPopover() {
        // Check if Touch ID is required
        if requiresHistoryAuth {
            // Check if within grace period
            if let lastAuth = lastAuthenticationTime,
               Date().timeIntervalSince(lastAuth) < authGracePeriod {
                // Within grace period, no auth needed
                showHistoryPopover()
            } else {
                authenticateWithBiometrics { [weak self] success in
                    guard success else { return }
                    Task { @MainActor in
                        self?.lastAuthenticationTime = Date()
                        // Small delay to let Touch ID dialog fully dismiss
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        self?.showHistoryPopover()
                    }
                }
            }
        } else {
            showHistoryPopover()
        }
    }

    @objc private func pasteFromMenu(_ sender: NSMenuItem) {
        let index = sender.tag
        guard index < clipboardManager.history.count else { return }

        if requiresHistoryAuth {
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

        if requiresHistoryAuth {
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
        button.image = menuBarTemplateImage(named: iconName)
    }

    @objc private func handleDismissForPaste() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    @objc private func handleReopenHistoryAfterPaste() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            if !popover.isShown {
                showHistoryPopover()
            }
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

        let captureScreenshotItem = NSMenuItem(
            title: CaptureWorkflow.screenshot.menuTitle,
            action: #selector(captureScreenshotFromMenu),
            keyEquivalent: ""
        )
        captureScreenshotItem.target = self
        menu.addItem(captureScreenshotItem)

        let captureTextItem = NSMenuItem(
            title: captureTextMenuItemTitle,
            action: #selector(captureTextFromMenu),
            keyEquivalent: ""
        )
        captureTextItem.target = self
        menu.addItem(captureTextItem)

        menu.addItem(NSMenuItem.separator())

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

        #if !APP_STORE && !SETAPP
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

    #if !APP_STORE && !SETAPP
    @objc private func checkForUpdates() {
        updateService.checkForUpdates()
    }
    #endif
}
