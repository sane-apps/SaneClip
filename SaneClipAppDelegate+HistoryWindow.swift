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

    /// Global-screen-point classifier for floating-window dismissal. Toolbar,
    /// title-bar, search, filter, and pause clicks are all still inside the
    /// window frame and must not close it. While a sheet is attached (Edit,
    /// Smart Clear confirmation, previews, save-preset) no click may dismiss:
    /// AppKit clamps a sheet's width to the parent window but not its height,
    /// so at small window sizes the sheet's Save/Cancel row hangs below
    /// `windowFrame` and its clicks would otherwise read as "outside".
    nonisolated static func shouldCloseHistoryWindowFromMouseDown(
        at point: NSPoint,
        windowFrame: NSRect,
        hasAttachedSheet: Bool = false
    ) -> Bool {
        !hasAttachedSheet && !windowFrame.contains(point)
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

    /// Gets the history UI out of the way of a synthesized paste. The floating
    /// panel is shown non-activating (see `showHistoryWindow`), so SaneClip never
    /// becomes the ACTIVE app — your app stays active and the synthetic Cmd+V
    /// lands there without us touching focus at all (this is exactly how Maccy
    /// works). So with keep-open ON we simply leave the window where it is: no
    /// hide, no reopen, no flicker. Without keep-open (or for the menu-bar
    /// popover) we still dismiss so it gets out of the way after you pick.
    @objc func handleDismissForPaste() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let historyWindow, historyWindow.isVisible {
            if SettingsModel.shared.keepPasteStackOpenBetweenPastes { return }
            removeHistoryWindowOutsideClickMonitor()
            historyWindow.orderOut(nil)
        }
    }

    /// Re-shows history after a paste when the flow asked to keep it open
    /// (e.g. paste-stack "keep open while consuming"). Routes to the window or
    /// the popover to match the user's chosen presentation.
    @objc func handleReopenHistoryAfterPaste() {
        // If keep-open kept the floating window visible (the non-activating panel
        // never had to hide for the paste), there is nothing to reopen — a
        // makeKeyAndOrderFront here would just re-flash the window.
        if let historyWindow, historyWindow.isVisible { return }
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

        // Show the floating panel WITHOUT making SaneClip the active app — this
        // is the crux of pasting into your app. `orderFrontRegardless()` brings
        // the panel forward "even if its application isn't active, without
        // changing either the key window or the main window" (Apple docs), and
        // `makeKey()` on a `.nonactivatingPanel` makes it key (so the search
        // field is typeable) WITHOUT activating SaneClip. Your app therefore
        // stays the ACTIVE app, so the synthetic Cmd+V lands in it. This is
        // exactly Maccy's pattern; `makeKeyAndOrderFront` instead activates
        // SaneClip and the paste hits our own window (the bug this replaces).
        if let historyWindow, historyWindow.isVisible {
            historyWindow.orderFrontRegardless()
            historyWindow.makeKey()
            installHistoryWindowOutsideClickMonitor()
            return
        }

        let window = historyWindow ?? makeHistoryWindow()
        historyWindow = window

        window.orderFrontRegardless()
        window.makeKey()
        installHistoryWindowOutsideClickMonitor()
    }

    func installHistoryWindowOutsideClickMonitor() {
        removeHistoryWindowOutsideClickMonitor()

        // Dismissal for the non-activating floating panel is driven SOLELY by
        // explicit mouse-downs run through the geometry classifier: a click
        // inside the window frame (toolbar, search, filter, pause) never closes
        // it; a click anywhere outside does. We deliberately do NOT close on app
        // deactivation. A `.nonactivatingPanel` means SaneClip is usually NOT
        // the active app while the panel is up (it floats over your current app
        // like Spotlight), so a `didResignActive` / `!NSApp.isActive` rule would
        // tear the window down the instant it opened — and again on every focus
        // change mid-use — which was Glenn's "clicking the toolbar closes the
        // window" bug. The global monitor still catches clicks into other apps,
        // so outside-click dismissal keeps working without the deactivation path.
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
    }

    private func handleHistoryWindowOutsideMouseDown(at point: NSPoint) {
        guard let historyWindow else {
            removeHistoryWindowOutsideClickMonitor()
            return
        }
        // Sheet attached (Edit, Smart Clear confirmation, previews,
        // save-preset): dismissal stays completely inert — no close and no
        // monitor teardown. `hidesOnDeactivate` can hide the panel mid-modal
        // on an app switch; it reappears with the sheet (and these monitors)
        // intact on reactivation.
        guard historyWindow.attachedSheet == nil else { return }
        guard historyWindow.isVisible else {
            removeHistoryWindowOutsideClickMonitor()
            return
        }
        guard Self.shouldCloseHistoryWindowFromMouseDown(
            at: point,
            windowFrame: historyWindow.frame,
            hasAttachedSheet: historyWindow.attachedSheet != nil
        ) else { return }
        closeHistoryWindowFromOutsideInteraction()
    }

    private func closeHistoryWindowFromOutsideInteraction() {
        guard let historyWindow else {
            removeHistoryWindowOutsideClickMonitor()
            return
        }
        // Never destroy the window while a sheet is attached — that would
        // throw away an in-progress edit.
        guard historyWindow.attachedSheet == nil else { return }
        guard historyWindow.isVisible else {
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
        let window = NonActivatingHistoryPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: ClipboardHistoryView.popoverWidth,
                height: ClipboardHistoryView.popoverMinHeight
            ),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.title = "SaneClip History"
        window.contentViewController = NSHostingController(rootView: historyRootView())
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.isFloatingPanel = true
        // Non-activating: the panel floats over whatever app you're in (like
        // Spotlight) without making SaneClip frontmost, so a paste lands in
        // that app and the keep-open pin never yanks focus back to us.
        // Dismissal is driven by the explicit outside-click monitors, not by
        // app deactivation (which may never fire for a panel that never
        // activates the app).
        window.hidesOnDeactivate = false
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
}
