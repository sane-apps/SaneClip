import AppKit
import CoreGraphics
import Foundation
@testable import SaneClip
import SaneUI
import SwiftUI
import Testing

/// Tests for the free-floating, resizable history window and clip drag-out —
/// features requested by a customer (Glenn) in July 2026.
struct HistoryWindowTests {
    private func projectRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test("SettingsModel round-trips floating-history-window preference")
    @MainActor
    func settingsModelFloatingHistoryWindowRoundTrip() throws {
        let settings = SettingsModel.shared
        let original = settings.useFloatingHistoryWindow
        defer { settings.useFloatingHistoryWindow = original }

        let payload: [String: Any] = [
            "version": 1,
            "useFloatingHistoryWindow": true,
        ]
        let exported = try JSONSerialization.data(withJSONObject: payload)

        settings.useFloatingHistoryWindow = false
        try settings.importSettings(from: exported)

        #expect(settings.useFloatingHistoryWindow == true)
    }

    @Test("Floating history window is resizable, remembers its frame, and routes clip triggers")
    func floatingHistoryWindowIsResizableAndPersistent() throws {
        let historyWindowSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("SaneClipAppDelegate+HistoryWindow.swift"),
            encoding: .utf8
        )
        let settingsSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("UI/Settings/GeneralSettingsView.swift"),
            encoding: .utf8
        )

        // Resizable window, sane bounds, remembered frame, on-screen clamp,
        // Pro-gated route. (Dismissal behavior is covered behaviorally by the
        // geometry-classifier tests below, not by fingerprinting here.)
        #expect(historyWindowSource.contains(".resizable"))
        #expect(historyWindowSource.contains("contentMinSize"))
        #expect(historyWindowSource.contains("contentMaxSize"))
        #expect(historyWindowSource.contains("setFrameAutosaveName(Self.historyWindowFrameAutosaveName)"))
        #expect(historyWindowSource.contains("ensureWindowOnScreen"))
        #expect(historyWindowSource.contains("min(max(frame.origin.x"))
        #expect(historyWindowSource.contains("if SettingsModel.shared.useFloatingHistoryWindow, licenseService.isPro"))

        // Non-activating Spotlight-style panel: it floats over your current app
        // WITHOUT activating SaneClip, so dismissal is driven SOLELY by the
        // outside-click monitors + geometry classifier — never by app
        // deactivation. REGRESSION GUARD for Glenn #1007 ("clicking the toolbar
        // closes the window"): on a non-activating panel SaneClip is usually
        // inactive while the window is up, so a resign-active / !NSApp.isActive
        // close would slam it shut the instant it opened and on every focus
        // change mid-use. None of those paths may return.
        #expect(historyWindowSource.contains(".nonactivatingPanel"))
        #expect(historyWindowSource.contains("window.hidesOnDeactivate = false"))
        #expect(historyWindowSource.contains("NSEvent.addGlobalMonitorForEvents"))
        #expect(historyWindowSource.contains("NSEvent.addLocalMonitorForEvents"))
        #expect(!historyWindowSource.contains("didResignActiveNotification"))
        #expect(!historyWindowSource.contains("if !NSApp.isActive"))
        #expect(!historyWindowSource.contains("Timer.scheduledTimer(withTimeInterval: 0.15"))
        #expect(!historyWindowSource.contains("NSApp.activate(ignoringOtherApps: true)"))
        #expect(!historyWindowSource.contains("NSApp.hide(nil)"))
        #expect(!historyWindowSource.contains("func applicationDidResignActive"))

        // Sheet-attached dismissal guard; no event-tap/overlay approach.
        #expect(historyWindowSource.contains("guard historyWindow.attachedSheet == nil else { return }"))
        #expect(historyWindowSource.contains("closeHistoryWindowFromOutsideInteraction"))
        #expect(!historyWindowSource.contains("CGEvent.tapCreate"))

        // Pro-gated floating-window setting is user-exposed.
        #expect(settingsSource.contains("Open history as a resizable floating window"))
        #expect(settingsSource.contains("feature: .floatingHistoryWindow"))
    }

    @Test("Floating history inside toolbar clicks do not dismiss the window")
    func floatingHistoryToolbarClicksStayInsideWindowFrame() {
        let frame = NSRect(x: 100, y: 200, width: 480, height: 640)

        // Glenn #1007 highlighted this top/title/search/filter/pause region.
        // It is inside the floating window frame and must not be treated like
        // an outside click.
        #expect(!SaneClipAppDelegate.shouldCloseHistoryWindowFromMouseDown(
            at: NSPoint(x: frame.minX + 24, y: frame.maxY - 20),
            windowFrame: frame
        ))
        #expect(!SaneClipAppDelegate.shouldCloseHistoryWindowFromMouseDown(
            at: NSPoint(x: frame.minX + 150, y: frame.maxY - 54),
            windowFrame: frame
        ))
        #expect(!SaneClipAppDelegate.shouldCloseHistoryWindowFromMouseDown(
            at: NSPoint(x: frame.maxX - 22, y: frame.maxY - 54),
            windowFrame: frame
        ))

        #expect(SaneClipAppDelegate.shouldCloseHistoryWindowFromMouseDown(
            at: NSPoint(x: frame.minX + 20, y: frame.maxY + 12),
            windowFrame: frame
        ))
        #expect(SaneClipAppDelegate.shouldCloseHistoryWindowFromMouseDown(
            at: NSPoint(x: frame.maxX + 12, y: frame.midY),
            windowFrame: frame
        ))
    }

    @Test("Floating history clicks do not dismiss the window while a sheet is attached")
    func floatingHistorySheetClicksKeepWindowAlive() {
        let frame = NSRect(x: 100, y: 200, width: 300, height: 360)

        // At the 300x360 minimum window size the edit sheet (min height 420)
        // hangs ~92pt below the parent frame — AppKit clamps a sheet's width
        // to the parent window but not its height — so its Save/Cancel row
        // sits below `historyWindow.frame`.
        let saveCancelClick = NSPoint(x: frame.midX, y: frame.minY - 46)

        // Without the sheet guard this click reads as "outside" and would
        // destroy the window (and the in-progress edit).
        #expect(SaneClipAppDelegate.shouldCloseHistoryWindowFromMouseDown(
            at: saveCancelClick,
            windowFrame: frame
        ))
        #expect(!SaneClipAppDelegate.shouldCloseHistoryWindowFromMouseDown(
            at: saveCancelClick,
            windowFrame: frame,
            hasAttachedSheet: true
        ))

        // Even a genuine outside click must not dismiss while modal.
        #expect(!SaneClipAppDelegate.shouldCloseHistoryWindowFromMouseDown(
            at: NSPoint(x: frame.maxX + 200, y: frame.midY),
            windowFrame: frame,
            hasAttachedSheet: true
        ))

        // Inside clicks stay non-dismissing regardless of the sheet.
        #expect(!SaneClipAppDelegate.shouldCloseHistoryWindowFromMouseDown(
            at: NSPoint(x: frame.midX, y: frame.midY),
            windowFrame: frame,
            hasAttachedSheet: true
        ))
    }

    @Test("Attached sheet really overhangs a min-size parent and stays guarded")
    @MainActor
    func attachedSheetOverhangKeepsWindowGuarded() async throws {
        let panel = NSPanel(
            contentRect: NSRect(x: 600, y: 400, width: 300, height: 360),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.orderFront(nil)
        defer {
            if let sheet = panel.attachedSheet { panel.endSheet(sheet) }
            panel.close()
        }

        // Mirror the edit sheet's minimum text-item size from ClipboardItemRow.
        let sheet = NSWindow(contentViewController: NSHostingController(
            rootView: Color.clear.frame(minWidth: 300, minHeight: 420)
        ))
        // Completion-handler overload: the async overload would suspend here
        // until the sheet is dismissed.
        panel.beginSheet(sheet) { _ in }

        // beginSheet attaches asynchronously; poll instead of a fixed sleep.
        for _ in 0 ..< 40 where panel.attachedSheet == nil {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        try #require(panel.attachedSheet != nil)

        // Geometry precondition: the sheet extends below the parent frame.
        #expect(sheet.frame.minY < panel.frame.minY)

        let clickInOverhang = NSPoint(x: sheet.frame.midX, y: sheet.frame.minY + 15)
        #expect(!panel.frame.contains(clickInOverhang))
        #expect(!SaneClipAppDelegate.shouldCloseHistoryWindowFromMouseDown(
            at: clickInOverhang,
            windowFrame: panel.frame,
            hasAttachedSheet: panel.attachedSheet != nil
        ))
    }

    @Test("Sparkle check frequency resolves and normalizes intervals")
    func sparkleCheckFrequencyBehavior() {
        #expect(SaneClip.SaneSparkleCheckFrequency.resolve(updateCheckInterval: 60 * 60 * 24) == .daily)
        #expect(SaneClip.SaneSparkleCheckFrequency.resolve(updateCheckInterval: 60 * 60 * 24 * 7) == .weekly)
        #expect(
            SaneClip.SaneSparkleCheckFrequency.normalizedInterval(from: 60 * 60 * 6) ==
                SaneClip.SaneSparkleCheckFrequency.daily.interval
        )
    }

    @Test("Sparkle settings UI stays channel-gated out of Setapp and App Store builds")
    func sparkleRowIsChannelGated() throws {
        // The Setapp archive scanner hard-fails on the SaneSparkleRow symbol,
        // so the app-local component must be compiled out for those channels
        // (a shared-library version reaches every consumer binary — that is
        // why it is app-local; see UI/Settings/SaneSparkleRow.swift header).
        let rowSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("UI/Settings/SaneSparkleRow.swift"),
            encoding: .utf8
        )
        #expect(rowSource.hasPrefix("// Direct-distribution ONLY"))
        #expect(rowSource.contains("#if !APP_STORE && !SETAPP"))
        #expect(rowSource.contains("struct SaneSparkleRow"))
    }

    @Test("Touch ID history lock gates the hotkey and Dock-reopen paths")
    func historyAuthGateBehavior() {
        let now = Date()

        // Lock off → always allowed, no prompt.
        #expect(SaneClipAppDelegate.historyAuthSatisfied(
            requiresAuth: false, lastAuth: nil, gracePeriod: 30, now: now
        ))
        // Lock on, never authenticated → must prompt.
        #expect(!SaneClipAppDelegate.historyAuthSatisfied(
            requiresAuth: true, lastAuth: nil, gracePeriod: 30, now: now
        ))
        // Lock on, authenticated 10s ago (inside 30s grace) → allowed.
        #expect(SaneClipAppDelegate.historyAuthSatisfied(
            requiresAuth: true, lastAuth: now.addingTimeInterval(-10), gracePeriod: 30, now: now
        ))
        // Lock on, grace expired → must prompt again.
        #expect(!SaneClipAppDelegate.historyAuthSatisfied(
            requiresAuth: true, lastAuth: now.addingTimeInterval(-31), gracePeriod: 30, now: now
        ))
    }

    @Test("Hotkey toggle and Dock reopen route through the Touch ID auth gate")
    func historyEntryPointsUseAuthGate() throws {
        let historyWindowSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("SaneClipAppDelegate+HistoryWindow.swift"),
            encoding: .utf8
        )
        let appSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("SaneClipApp.swift"),
            encoding: .utf8
        )

        // toggleHistoryWindow (⌘⇧⌃Y hotkey) must not open the Pro window directly in Basic.
        #expect(historyWindowSource.contains("guard licenseService.isPro else"))
        #expect(historyWindowSource.contains("withHistoryAuth { [weak self] in self?.showHistoryPopover() }"))
        #expect(historyWindowSource.contains("withHistoryAuth { [weak self] in self?.showHistoryWindow() }"))
        // Dock/Finder reopen must go through the same gate.
        #expect(appSource.contains("withHistoryAuth { [weak self] in self?.showHistoryPopover() }"))
        // The gate delegates its decision to the tested pure function.
        #expect(historyWindowSource.contains("historyAuthSatisfied("))
    }

    @Test("Floating history is a non-activating panel: paste lands in the target app without a focus steal")
    func floatingWindowPasteReturnsFocus() throws {
        let historyWindowSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("SaneClipAppDelegate+HistoryWindow.swift"),
            encoding: .utf8
        )
        let appSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("SaneClipApp.swift"),
            encoding: .utf8
        )
        // The panel is non-activating (Spotlight-style): it floats over the
        // current app without making SaneClip frontmost.
        #expect(historyWindowSource.contains(".nonactivatingPanel"))
        // The dismiss handler just orders the panel out; because we are never
        // frontmost, the synthetic Cmd+V lands in the target app. It must NOT
        // hide the whole app any more, and showing must NOT activate SaneClip
        // — either would steal focus on the keep-open reopen.
        #expect(historyWindowSource.contains("func handleDismissForPaste()"))
        #expect(historyWindowSource.contains("historyWindow.orderOut(nil)"))
        #expect(!historyWindowSource.contains("NSApp.hide(nil)"))
        #expect(!historyWindowSource.contains("NSApp.activate(ignoringOtherApps: true)"))
        // Reopen-after-paste routes to the window when floating.
        #expect(historyWindowSource.contains("func handleReopenHistoryAfterPaste()"))
        // A second menu-bar click closes the floating window.
        #expect(appSource.contains("historyWindow.close() // second menu-bar click closes the floating window"))
    }

    @Test("Killer update: keyboard nav, honest quick-paste hint, and discoverability wiring")
    func killerUpdateUXWiring() throws {
        let historyView = try String(
            contentsOf: projectRootURL().appendingPathComponent("UI/History/ClipboardHistoryView.swift"),
            encoding: .utf8
        )
        let filterBar = try String(
            contentsOf: projectRootURL().appendingPathComponent("UI/History/HistoryFilterBar.swift"),
            encoding: .utf8
        )
        let generalSettings = try String(
            contentsOf: projectRootURL().appendingPathComponent("UI/Settings/GeneralSettingsView.swift"),
            encoding: .utf8
        )
        let rowSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("UI/History/ClipboardItemRow.swift"),
            encoding: .utf8
        )
        let keyboardSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("UI/History/HistoryListKeyboardShortcuts.swift"),
            encoding: .utf8
        )

        // Auto-scroll selection into view.
        #expect(historyView.contains("ScrollViewReader { proxy in"))
        #expect(historyView.contains("proxy.scrollTo(allItems[newIndex].id, anchor: .center)"))
        // Extra keyboard navigation (bundled in the shortcuts modifier).
        #expect(keyboardSource.contains(".onKeyPress(.home)"))
        #expect(keyboardSource.contains(".onKeyPress(.end)"))
        #expect(keyboardSource.contains(".onKeyPress(.pageUp)"))
        #expect(keyboardSource.contains(".onKeyPress(.pageDown)"))
        #expect(keyboardSource.contains(".onKeyPress(.escape)"))
        #expect(historyView.contains("func togglePinSelected()"))
        #expect(historyView.contains(".modifier(HistoryListKeyboardShortcuts("))
        // Honest quick-paste hint (no lie when pinned/filtered).
        #expect(historyView.contains("func quickPasteHint(for index: Int) -> String?"))
        #expect(historyView.contains("shortcutHint: quickPasteHint(for: index)"))
        // Filter row scrolls instead of clipping.
        #expect(filterBar.contains("ScrollView(.horizontal, showsIndicators: false)"))
        // Floating-window toggle is discoverable in General settings.
        #expect(generalSettings.contains("Open history as a resizable floating window"))
        // Drag-out affordance on hover for non-pinned rows.
        #expect(rowSource.contains("Drag to another app"))
    }

    @Test("Clip rows drag out only when not pinned so pinned reorder survives")
    func clipRowsExposeDragProvider() throws {
        let rowSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("UI/History/ClipboardItemRow.swift"),
            encoding: .utf8
        )
        // Drag-out is Pro-gated and still disabled for pinned rows so they keep List `.onMove`.
        #expect(rowSource.contains(".onDragOut(enabled: isPro && !isPinned) { dragItemProvider() }"))
        #expect(rowSource.contains("func onDragOut(enabled: Bool"))
        #expect(rowSource.contains("func dragItemProvider() -> NSItemProvider"))
    }

    @Test("Wide floating window splits into list + preview pane; popover stays single-column")
    func previewPaneGatingAndContent() throws {
        let historySource = try String(
            contentsOf: projectRootURL().appendingPathComponent("UI/History/ClipboardHistoryView.swift"),
            encoding: .utf8
        )
        let paneSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("UI/History/ClipPreviewPane.swift"),
            encoding: .utf8
        )
        // Gated on Pro + a width threshold the fixed 320-pt popover can never
        // reach, so the pane is exclusive to a wide floating window and never
        // cramps a narrow one.
        #expect(historySource.contains("previewPaneThreshold"))
        #expect(historySource.contains("availableWidth >= Self.previewPaneThreshold"))
        #expect(historySource.contains("isPro && availableWidth"))
        #expect(historySource.contains("if showsPreviewPane"))
        #expect(historySource.contains("ClipPreviewPane("))
        // The threshold sits above the popover width and below the window max,
        // so at least one real window size shows the pane and the popover never
        // does.
        #expect(ClipboardHistoryView.popoverWidth < 640)
        #expect(ClipboardHistoryView.windowMaxWidth >= 640)
        // The pane carries the recognition metadata people actually choose by,
        // and reuses the same paste/pin paths as the rest of the UI.
        #expect(paneSource.contains("Source app"))
        #expect(paneSource.contains("Captured"))
        #expect(paneSource.contains("pasteFromHistory(item:"))
        #expect(paneSource.contains("togglePin(item:"))
    }

    @Test("Footer keeps item count and actions reachable at narrow widths")
    func footerAvoidsSquash() throws {
        let footerSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("UI/History/HistoryFooterView.swift"),
            encoding: .utf8
        )
        // Item count + Settings + Smart Clear stay pinned. Secondary controls
        // get a second row; the footer must not use a horizontal scroller
        // because its indicator covered "Clear Queue" in Glenn's screenshot.
        #expect(footerSource.contains("private var itemCountLabel"))
        #expect(footerSource.contains("private var secondaryControls"))
        #expect(!footerSource.contains("ScrollView(.horizontal"))
        #expect(footerSource.contains("private var showsSecondaryControls"))
        #expect(footerSource.contains("private var settingsButton"))
        #expect(footerSource.contains("private var smartClearButton"))
        // The merge group carries no leading divider; the single separating
        // divider lives in secondaryControls' one-row layout only.
        #expect(footerSource.contains("private var mergeControls"))
        #expect(footerSource.components(separatedBy: "Divider().frame(height: 14)").count == 2)
        // Overflow guard (Glenn's "can't reach Clear Queue / Stack"): the footer
        // drops to one group per row via ViewThatFits when they can't share a
        // row at 300-320pt — no clipped trailing edge, no horizontal scroller.
        #expect(footerSource.contains("ViewThatFits(in: .horizontal)"))
        // The Pro paste-stack cluster is gated on having something to act on,
        // so the empty "0" chip never claims a footer row in the common
        // just-opened state; the whole second row collapses when idle.
        #expect(footerSource.contains("private var showsPasteStackCluster"))
        #expect(footerSource.contains("!clipboardManager.pasteStack.isEmpty || showPasteStackPanel"))
        #expect(footerSource.contains("private var pasteStackCluster"))
        #expect(footerSource.contains("private var pasteStackUpsell"))
        // The second row is no longer shown just because the user is Pro.
        #expect(!footerSource.contains("!mergeQueueIDs.isEmpty || isPro || licenseService != nil"))
    }
}
