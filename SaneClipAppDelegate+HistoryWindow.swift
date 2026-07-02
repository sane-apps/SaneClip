import AppKit
import SwiftUI

extension SaneClipAppDelegate {
    /// UserDefaults-backed autosave key so the floating window remembers its
    /// last size and screen position between launches (Glenn's request #3).
    static let historyWindowFrameAutosaveName = "SaneClipHistoryWindowFrame"

    func showHistoryPopover() {
        // When the user prefers a free-floating window, route every history
        // trigger to it instead of the menu-bar-anchored popover.
        if SettingsModel.shared.useFloatingHistoryWindow, licenseService.isPro {
            showHistoryWindow()
            return
        }
        if SettingsModel.shared.openHistoryAtCursor {
            showPopoverAtCursor()
        } else {
            showPopoverAtButton()
        }
    }

    /// Flexible root view for the resizable floating window. Unlike the popover
    /// (fixed width), this stretches to fill whatever size the user drags to,
    /// clamped by the window's `contentMinSize`/`contentMaxSize`.
    func historyRootView() -> some View {
        ClipboardHistoryView(clipboardManager: clipboardManager, licenseService: licenseService)
            .frame(
                minWidth: ClipboardHistoryView.windowMinWidth,
                maxWidth: .infinity,
                minHeight: ClipboardHistoryView.windowMinHeight,
                maxHeight: .infinity,
                alignment: .top
            )
            .preferredColorScheme(.dark)
    }

    /// Pure gate decision so the Touch ID lock logic is testable: returns true
    /// when history may open WITHOUT prompting (lock off, or still inside the
    /// grace window after a successful authentication).
    nonisolated static func historyAuthSatisfied(
        requiresAuth: Bool,
        lastAuth: Date?,
        gracePeriod: TimeInterval,
        now: Date = Date()
    ) -> Bool {
        guard requiresAuth else { return true }
        guard let lastAuth else { return false }
        return now.timeIntervalSince(lastAuth) < gracePeriod
    }

    /// Runs `action` behind the same Touch ID gate as the menu-bar popover
    /// path (requiresHistoryAuth + grace period). The ⌘⇧⌃Y hotkey and
    /// Dock-reopen paths previously skipped authentication entirely, so a
    /// locked history could be opened without Touch ID.
    func withHistoryAuth(_ action: @escaping @MainActor () -> Void) {
        if Self.historyAuthSatisfied(
            requiresAuth: requiresHistoryAuth,
            lastAuth: lastAuthenticationTime,
            gracePeriod: authGracePeriod
        ) {
            action()
            return
        }
        authenticateWithBiometrics { [weak self] success in
            guard success else { return }
            Task { @MainActor in
                self?.lastAuthenticationTime = Date()
                // Small delay to let the Touch ID dialog fully dismiss.
                try? await Task.sleep(nanoseconds: 150_000_000)
                action()
            }
        }
    }

    func toggleHistoryWindow() {
        if popover.isShown {
            popover.performClose(nil)
        }

        if let historyWindow, historyWindow.isVisible {
            removeHistoryWindowOutsideClickMonitor()
            historyWindow.close()
            return
        }

        guard licenseService.isPro else {
            withHistoryAuth { [weak self] in self?.showHistoryPopover() }
            return
        }
        withHistoryAuth { [weak self] in self?.showHistoryWindow() }
    }

    /// Hides the history UI before a paste is synthesized. For the floating
    /// window we must hide the *app* (not just the panel): showing the window
    /// activated SaneClip, so a bare `orderOut` would leave SaneClip frontmost
    /// and the synthetic Cmd+V would land on us instead of the target app.
    @objc func handleDismissForPaste() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let historyWindow, historyWindow.isVisible {
            removeHistoryWindowOutsideClickMonitor()
            historyWindow.orderOut(nil)
            NSApp.hide(nil)
        }
    }

    /// Re-shows history after a paste when the flow asked to keep it open
    /// (e.g. paste-stack "keep open while consuming"). Routes to the window or
    /// the popover to match the user's chosen presentation.
    @objc func handleReopenHistoryAfterPaste() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            if SettingsModel.shared.useFloatingHistoryWindow, licenseService.isPro {
                showHistoryWindow()
            } else if !popover.isShown {
                showHistoryPopover()
            }
        }
    }

    func showHistoryWindow() {
        if popover.isShown {
            popover.performClose(nil)
        }

        if let historyWindow, historyWindow.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            historyWindow.makeKeyAndOrderFront(nil)
            installHistoryWindowOutsideClickMonitor()
            return
        }

        let window = historyWindow ?? makeHistoryWindow()
        historyWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        installHistoryWindowOutsideClickMonitor()
    }

    func installHistoryWindowOutsideClickMonitor() {
        removeHistoryWindowOutsideClickMonitor()

        historyWindowOutsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.handleHistoryWindowOutsideMouseDown(at: NSEvent.mouseLocation)
            }
        }
        historyWindowOutsideClickLocalMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            DispatchQueue.main.async { [weak self] in
                let screenPoint = event.window?.convertPoint(toScreen: event.locationInWindow)
                    ?? NSEvent.mouseLocation
                self?.handleHistoryWindowOutsideMouseDown(at: screenPoint)
            }
            return event
        }
        historyWindowResignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.closeHistoryWindowFromOutsideInteraction()
            }
        }
        historyWindowOutsideClickTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.historyWindow?.isVisible == true else { return }
                if !NSApp.isActive {
                    self.closeHistoryWindowFromOutsideInteraction()
                }
            }
        }
        installHistoryWindowOutsideClickEventTap()
    }

    func removeHistoryWindowOutsideClickMonitor() {
        if let historyWindowOutsideClickMonitor {
            NSEvent.removeMonitor(historyWindowOutsideClickMonitor)
            self.historyWindowOutsideClickMonitor = nil
        }
        if let historyWindowOutsideClickLocalMonitor {
            NSEvent.removeMonitor(historyWindowOutsideClickLocalMonitor)
            self.historyWindowOutsideClickLocalMonitor = nil
        }
        if let historyWindowResignActiveObserver {
            NotificationCenter.default.removeObserver(historyWindowResignActiveObserver)
            self.historyWindowResignActiveObserver = nil
        }
        historyWindowOutsideClickTimer?.invalidate()
        historyWindowOutsideClickTimer = nil
        if let historyWindowOutsideClickRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), historyWindowOutsideClickRunLoopSource, .commonModes)
            self.historyWindowOutsideClickRunLoopSource = nil
        }
        if let historyWindowOutsideClickEventTap {
            CFMachPortInvalidate(historyWindowOutsideClickEventTap)
            self.historyWindowOutsideClickEventTap = nil
        }
    }

    private func installHistoryWindowOutsideClickEventTap() {
        let mask = (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.otherMouseDown.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, _, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let delegate = Unmanaged<SaneClipAppDelegate>.fromOpaque(userInfo).takeUnretainedValue()
                let point = event.location
                Task { @MainActor in
                    delegate.handleHistoryWindowOutsideMouseDown(at: point)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: userInfo
        ) else {
            return
        }

        historyWindowOutsideClickEventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        historyWindowOutsideClickRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleHistoryWindowOutsideMouseDown(at point: NSPoint) {
        guard let historyWindow, historyWindow.isVisible else {
            removeHistoryWindowOutsideClickMonitor()
            return
        }
        guard !historyWindow.frame.contains(point) else { return }
        closeHistoryWindowFromOutsideInteraction()
    }

    private func closeHistoryWindowFromOutsideInteraction() {
        guard let historyWindow, historyWindow.isVisible else {
            removeHistoryWindowOutsideClickMonitor()
            return
        }
        historyWindow.orderOut(nil)
        historyWindow.close()
        self.historyWindow = nil
        removeHistoryWindowOutsideClickMonitor()
    }

    /// Builds the resizable floating history panel. Adds `.resizable` to the
    /// style mask (Glenn's request #1/#2), constrains resizing to sane bounds,
    /// and restores the remembered frame — centering only on first use.
    private func makeHistoryWindow() -> NSPanel {
        let window = NSPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: ClipboardHistoryView.popoverWidth,
                height: ClipboardHistoryView.popoverMinHeight
            ),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "SaneClip History"
        window.contentViewController = NSHostingController(rootView: historyRootView())
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.isFloatingPanel = true
        // Match popover dismissal: once the user clicks another app/desktop
        // without pasting, the floating history window gets out of the way.
        window.hidesOnDeactivate = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Keep resizing "flexible but not infinite".
        window.contentMinSize = NSSize(
            width: ClipboardHistoryView.windowMinWidth,
            height: ClipboardHistoryView.windowMinHeight
        )
        window.contentMaxSize = NSSize(
            width: ClipboardHistoryView.windowMaxWidth,
            height: ClipboardHistoryView.windowMaxHeight
        )

        // Restore last size + position; fall back to centered on first launch.
        window.setFrameAutosaveName(Self.historyWindowFrameAutosaveName)
        if !window.setFrameUsingName(Self.historyWindowFrameAutosaveName) {
            window.center()
        }
        ensureWindowOnScreen(window)
        return window
    }

    /// Keeps the restored frame reachable: clamps the window's origin so it sits
    /// fully within the active screen's visible area. Guards against a saved
    /// frame that is off-screen or mostly-clipped (e.g. a display was
    /// disconnected or resized since last launch) leaving the title bar
    /// ungrabbable. Centers instead if the window is larger than the screen.
    private func ensureWindowOnScreen(_ window: NSWindow) {
        let screen = window.screen ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        var frame = window.frame

        if frame.width > visible.width || frame.height > visible.height {
            frame.origin.x = visible.midX - frame.width / 2
            frame.origin.y = visible.midY - frame.height / 2
        } else {
            frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)
            frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)
        }

        if frame != window.frame {
            window.setFrame(frame, display: false)
        }
    }

    func showPopoverAtButton() {
        guard let button = statusItem.button else { return }
        resetHistoryPopoverSize()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        if let popoverWindow = popover.contentViewController?.view.window {
            popoverWindow.makeKey()
        }
    }

    func showPopoverAtCursor() {
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

    func resetHistoryPopoverSize() {
        let size = NSSize(
            width: ClipboardHistoryView.popoverWidth,
            height: ClipboardHistoryView.popoverMinHeight
        )
        popover.contentSize = size
        popover.contentViewController?.preferredContentSize = size
    }

    func applicationDidResignActive(_: Notification) {
        closeHistoryWindowFromOutsideInteraction()
    }
}
