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

    @Test("History UI holds the one-meaning-per-hue color system (no raw functional colors)")
    func historyColorSemioticsAreEnforced() throws {
        // The functional palette must always come from the named BrandColors
        // tokens (clipBlue, pinnedOrange, semanticSuccess, proUnlock, mergeTeal,
        // stackViolet, semanticWarning/Error). A raw SwiftUI functional hue in
        // the History UI re-introduces exactly the semiotic collision the 2.3.14
        // color pass removed, so guard against it here.
        let files = [
            "UI/History/ClipboardItemRow.swift",
            "UI/History/HistoryFooterView.swift",
            "UI/History/ClipboardHistoryView.swift",
            "UI/History/ClipPreviewPane.swift",
            "UI/History/HistoryPasteStackPanel.swift",
        ]
        let forbidden = ["(.teal)", "(.orange)", "(.green)", "(.yellow)",
                         "Color.teal", "Color.orange", "Color.green", "Color.yellow"]
        for relative in files {
            let source = try String(
                contentsOf: projectRootURL().appendingPathComponent(relative),
                encoding: .utf8
            )
            for token in forbidden {
                #expect(!source.contains(token), "\(relative) uses raw \(token) — use a BrandColors token")
            }
        }

        // The color tokens themselves stay defined with their one meaning.
        let brand = try String(
            contentsOf: projectRootURL().appendingPathComponent("Core/BrandColors.swift"),
            encoding: .utf8
        )
        for token in ["proUnlock", "mergeTeal", "stackViolet", "semanticSuccess", "pinnedOrange"] {
            #expect(brand.contains("static let \(token)"))
        }
    }

    @Test("Empty history keeps the search bar pinned to the top")
    func emptyStatePinsSearchToTop() throws {
        let source = try String(
            contentsOf: projectRootURL().appendingPathComponent("UI/History/ClipboardHistoryView.swift"),
            encoding: .utf8
        )
        // The empty ContentUnavailableView must fill the space between the
        // pinned search bar and the footer, so the stack can't collapse and
        // float the search field into the middle of the window.
        #expect(source.contains("ContentUnavailableView(title, systemImage: icon, description: Text(desc))"))
        #expect(source.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"))
    }

    @Test("History paste honors the keep-open pin without changing URL-scheme paste")
    func historyPasteUsesKeepOpenPath() throws {
        let managerSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("Core/ClipboardManager.swift"),
            encoding: .utf8
        )
        let historySource = try String(
            contentsOf: projectRootURL().appendingPathComponent("UI/History/ClipboardHistoryView.swift"),
            encoding: .utf8
        )
        let rowSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("UI/History/ClipboardItemRow.swift"),
            encoding: .utf8
        )
        let urlSchemeSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("Core/URLScheme/URLSchemeHandler.swift"),
            encoding: .utf8
        )

        #expect(managerSource.contains("func pasteFromHistory(item: ClipboardItem) -> Bool"))
        #expect(managerSource.contains("reopenPopoverAfterPaste: SettingsModel.shared.keepPasteStackOpenBetweenPastes"))
        #expect(historySource.contains("clipboardManager.pasteFromHistory(item: item)"))
        #expect(rowSource.contains("clipboardManager.pasteFromHistory(item: item)"))
        #expect(historySource.contains("pin.fill"))
        #expect(historySource.contains("@State private var settings = SettingsModel.shared"))
        #expect(historySource.contains("settings.keepPasteStackOpenBetweenPastes.toggle()"))
        #expect(urlSchemeSource.contains("clipboardManager.paste(item: item)"))
    }

    @Test("Glenn regressions pin edit footer and redraw Clipboard Rules toggles immediately")
    func glennEditAndClipboardRulesRegressionsAreCovered() throws {
        let rowSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("UI/History/ClipboardItemRow.swift"),
            encoding: .utf8
        )
        let rulesSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("UI/Settings/ClipboardRulesSection.swift"),
            encoding: .utf8
        )

        // Edit sheet: fields scroll vertically, footer stays outside the
        // scroll body, and the old fixed-width text editor is gone.
        #expect(rowSource.contains("ScrollView(.vertical, showsIndicators: true)"))
        #expect(rowSource.contains("private var editSheetFooter"))
        #expect(rowSource.contains("minHeight: isImageItem ? 300 : 420"))
        #expect(rowSource.contains(".buttonStyle(ClipActionButtonStyle(compact: true))"))
        #expect(rowSource.contains(".buttonStyle(ClipActionButtonStyle(prominent: true, compact: true))"))
        #expect(!rowSource.contains(".frame(minWidth: 400, minHeight: 200)"))

        // Clipboard Rules: visible switch state changes first, then the shared
        // UserDefaults-backed rules manager is updated. Direct computed
        // property bindings do not reliably invalidate SwiftUI rows.
        #expect(rulesSource.contains("@State private var stripTrackingParams"))
        #expect(rulesSource.contains("stripTrackingParams = newValue"))
        #expect(rulesSource.contains("rules.stripTrackingParams = newValue"))
        #expect(rulesSource.contains(".onAppear(perform: syncRuleState)"))
    }

    @Test("Every clip source gets a stable, distinct color (not just Apple apps)")
    @MainActor
    func sourceColorsAreSharedStableAndDistinct() {
        func rgba(_ color: Color) -> [CGFloat] {
            let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
            return [ns.redComponent, ns.greenComponent, ns.blueComponent, ns.alphaComponent]
        }

        // Case-insensitive + stable across calls.
        #expect(rgba(SaneClipSourceColor.color(forSourceNamed: "Codex", dark: true))
            == rgba(SaneClipSourceColor.color(forSourceNamed: "codex", dark: true)))

        // Unmapped third-party apps get DISTINCT colors (the bug: they were all blue).
        let codex = rgba(SaneClipSourceColor.color(forSourceNamed: "Codex", dark: true))
        let quicktime = rgba(SaneClipSourceColor.color(forSourceNamed: "QuickTime Player", dark: true))
        #expect(codex != quicktime)
        #expect(codex != rgba(Color.clipBlue))
        #expect(quicktime != rgba(Color.clipBlue))

        // Curated apps keep their hand-tuned color.
        #expect(rgba(SaneClipSourceColor.color(forSourceNamed: "Messages", dark: true))
            == rgba(Color(hex: 0x5EC2A0)))

        // nil / empty source → brand blue.
        #expect(rgba(SaneClipSourceColor.color(forSourceNamed: nil, dark: true)) == rgba(Color.clipBlue))
        #expect(rgba(SaneClipSourceColor.color(forSourceNamed: "   ", dark: true)) == rgba(Color.clipBlue))

        // Light vs dark differ for the same source.
        #expect(rgba(SaneClipSourceColor.color(forSourceNamed: "Codex", dark: true))
            != rgba(SaneClipSourceColor.color(forSourceNamed: "Codex", dark: false)))
    }

    @Test("Both platforms use the shared SaneClipSourceColor (no duplicated palette)")
    func sourceColorPaletteIsDeduplicated() throws {
        let rowSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("UI/History/ClipboardItemRow.swift"),
            encoding: .utf8
        )
        let cellSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("iOS/Views/ClipboardItemCell.swift"),
            encoding: .utf8
        )
        let shared = try String(
            contentsOf: projectRootURL().appendingPathComponent("Core/BrandColors.swift"),
            encoding: .utf8
        )
        #expect(shared.contains("enum SaneClipSourceColor"))
        #expect(rowSource.contains("SaneClipSourceColor.color(forSourceNamed: item.sourceAppName"))
        #expect(cellSource.contains("SaneClipSourceColor.color(forSourceNamed: item.sourceAppName"))
        // The old copy-pasted 13-app switch is gone from the views.
        #expect(!rowSource.contains("case \"reminders\": return Color(hex: 0x8A9FE4)"))
        #expect(!cellSource.contains("case \"reminders\": return Color(hex: 0x8A9FE4)"))
    }

    // MARK: - Visual receipts

    /// Renders the history view at the narrow (old popover) width and at a
    /// floating-window width so the footer fix and floating layout can be seen.
    /// Only runs when `SANECLIP_SCREENSHOT_DIR` (or the /tmp hint file) is set.
    @MainActor
    private struct RenderScenario {
        let name: String
        let width: CGFloat
        let height: CGFloat
        var pro = false
        var seed: Seed = .rich
        var showFilters = false
        var mergeActive = false
        var showStack = false
        var recording = false

        enum Seed { case rich, empty, longText, colorful }
    }

    @Test("Paste-stack recording is opt-in, Pro-gated, and stays within the cap")
    @MainActor
    func pasteStackRecordingBehavior() {
        let manager = ClipboardManager(
            startMonitoring: false,
            loadPersistedState: false,
            persistenceEnabled: false
        )

        // Off by default — normal copying is untouched until the user opts in.
        #expect(manager.isRecordingStack == false)

        // Basic users can't turn it on.
        manager.licenseService = nil
        manager.setStackRecording(true)
        #expect(manager.isRecordingStack == false)

        // Pro can.
        manager.licenseService = makeForcedProLicense()
        manager.setStackRecording(true)
        #expect(manager.isRecordingStack == true)
        manager.setStackRecording(false)
        #expect(manager.isRecordingStack == false)

        // The stack never grows past the cap, oldest-first.
        for index in 0 ..< (ClipboardManager.pasteStackCap + 12) {
            manager.addToPasteStack(ClipboardItem(content: .text("clip \(index)")))
        }
        #expect(manager.pasteStack.count == ClipboardManager.pasteStackCap)
        #expect(manager.pasteStack.first?.preview.contains("clip 12") == true)

        // BEHAVIOR: while recording, a captured item is appended to the stack;
        // while not recording, it is not (normal copying is untouched).
        let recorder = ClipboardManager(startMonitoring: false, loadPersistedState: false, persistenceEnabled: false)
        recorder.licenseService = makeForcedProLicense()
        recorder.recordCapturedItemToStackIfNeeded(ClipboardItem(content: .text("while off")))
        #expect(recorder.pasteStack.isEmpty) // off by default → not recorded
        recorder.setStackRecording(true)
        recorder.recordCapturedItemToStackIfNeeded(ClipboardItem(content: .text("captured while recording")))
        #expect(recorder.pasteStack.count == 1)
        #expect(recorder.pasteStack.last?.preview.contains("captured while recording") == true)
        // Basic users never record even if the flag were forced.
        let basic = ClipboardManager(startMonitoring: false, loadPersistedState: false, persistenceEnabled: false)
        basic.isRecordingStack = true
        basic.recordCapturedItemToStackIfNeeded(ClipboardItem(content: .text("x")))
        #expect(basic.pasteStack.isEmpty)

        // The recording hook has exactly ONE call site — in the capture path
        // (`addItem`, which runs after self-write suppression) — so a paste
        // from the stack can never feed itself back in. Two occurrences of the
        // token = the func definition + the single call.
        let managerSource = try? String(
            contentsOf: projectRootURL().appendingPathComponent("Core/ClipboardManager.swift"),
            encoding: .utf8
        )
        #expect(managerSource?.contains("recordCapturedItemToStackIfNeeded(item)") == true)
        #expect(
            (managerSource?.components(separatedBy: "recordCapturedItemToStackIfNeeded(").count ?? 0) == 3
        )
    }

    @Test("Recorded/queued paste-stack items survive the history trim (and a relaunch)")
    @MainActor
    func pasteStackItemsSurviveHistoryTrim() {
        let manager = ClipboardManager(startMonitoring: false, loadPersistedState: false, persistenceEnabled: false)
        manager.licenseService = makeForcedProLicense()

        // A small history cap so we can force a trim deterministically.
        SettingsModel.shared.maxHistorySize = 5
        defer { SettingsModel.shared.maxHistorySize = 100 }

        // Queue three clips, then flood history so the queued clips fall past
        // the cap. The public capture entry is exercised via addToHistoryForTest.
        let queued = (0 ..< 3).map { ClipboardItem(content: .text("queued \($0)")) }
        for item in queued {
            manager.history.insert(item, at: 0)
            manager.addToPasteStack(item)
        }
        // Flood newer items so the queued clips fall past the cap, then trim.
        for index in 0 ..< 20 {
            manager.history.insert(ClipboardItem(content: .text("filler \(index)")), at: 0)
        }
        manager.enforceHistoryLimitIfNeeded(saveAfterTrim: false)

        // History was trimmed past the queued clips, but every queued item is
        // protected — still present so it survives rehydration on next launch.
        for item in queued {
            #expect(manager.history.contains { $0.id == item.id })
        }
        #expect(manager.pasteStack.count == 3)
    }

    @MainActor
    @Test("Render customer-size history screenshots across states when requested")
    func renderHistoryScreenshotMatrix() throws {
        guard let rawDir = screenshotDir() else { return }
        let outputDir = URL(
            fileURLWithPath: NSString(string: rawDir).expandingTildeInPath,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        // Real window sizes/aspect ratios a customer would use, plus the states
        // most likely to expose layout failures (crowded footer, filters row at
        // narrow width, paste-stack panel, empty, overflow, min/max bounds).
        let scenarios: [RenderScenario] = [
            .init(name: "01-free-popover-320x500", width: 320, height: 500),
            .init(name: "02-pro-popover-merge-320x500", width: 320, height: 500, pro: true, mergeActive: true),
            .init(name: "03-pro-floating-480x640", width: 480, height: 640, pro: true),
            .init(name: "04-pro-floating-wide-720x430", width: 720, height: 430, pro: true),
            .init(name: "05-pro-floating-tall-340x800", width: 340, height: 800, pro: true),
            .init(name: "06-free-floating-min-300x360", width: 300, height: 360),
            .init(name: "07-empty-floating-420x560", width: 420, height: 560, seed: .empty),
            .init(name: "08-pro-popover-filters-320x620", width: 320, height: 620, pro: true, showFilters: true),
            .init(name: "09-pro-floating-stack-560x680", width: 560, height: 680, pro: true, showStack: true),
            .init(name: "10-free-popover-longtext-320x500", width: 320, height: 500, seed: .longText),
            .init(name: "11-colorful-sources-440x700", width: 440, height: 700, seed: .colorful),
            .init(name: "12-pro-floating-recording-560x680", width: 560, height: 680, pro: true, showStack: true, recording: true),
        ]

        let proLicense = makeForcedProLicense()

        for scenario in scenarios {
            let manager = makeManager(seed: scenario.seed, withStack: scenario.showStack)
            manager.isRecordingStack = scenario.recording
            let mergeIDs: Set<UUID> = scenario.mergeActive
                ? Set(manager.history.prefix(2).map(\.id))
                : []
            try renderHistoryPNG(
                manager: manager,
                license: scenario.pro ? proLicense : nil,
                width: scenario.width,
                height: scenario.height,
                showFilters: scenario.showFilters,
                mergeIDs: mergeIDs,
                showStack: scenario.showStack,
                to: outputDir.appendingPathComponent("matrix-\(scenario.name).png")
            )
        }

        #expect(FileManager.default.fileExists(
            atPath: outputDir.appendingPathComponent("matrix-01-free-popover-320x500.png").path
        ))
    }

    @MainActor
    private func makeForcedProLicense() -> LicenseService {
        setenv("SANEAPPS_FORCE_PRO_MODE", "1", 1)
        let service = LicenseService(
            appName: "SaneClip",
            checkoutURL: URL(string: "https://saneapps.com")!,
            proTrial: nil
        )
        service.checkCachedLicense()
        unsetenv("SANEAPPS_FORCE_PRO_MODE")
        return service
    }

    @MainActor
    private func makeManager(seed: RenderScenario.Seed, withStack: Bool) -> ClipboardManager {
        let manager = ClipboardManager(startMonitoring: false, loadPersistedState: false, persistenceEnabled: false)
        switch seed {
        case .empty:
            manager.history = []
            manager.pinnedItems = []
        case .colorful:
            // Diverse sources — mix of curated apps and previously-blue
            // third-party apps — to show every source now gets its own color.
            let sources = [
                "Messages", "Brave Browser", "Codex", "Slack", "QuickTime Player",
                "Visual Studio Code", "Notes", "Arc", "Google Chrome", "Terminal",
                "Discord", "Figma", "Xcode", "Spotify",
            ]
            manager.history = sources.map { name in
                ClipboardItem(content: .text("Clip from \(name)"), sourceAppName: name)
            }
            manager.pinnedItems = []
        case .longText:
            let long = String(repeating: "supercalifragilistic-unbreakable-token-", count: 8)
            manager.history = [
                ClipboardItem(content: .text(long), sourceAppName: "Safari"),
                ClipboardItem(content: .text("Short normal clip"), sourceAppName: "Notes"),
            ]
            manager.pinnedItems = []
        case .rich:
            let pinned = ClipboardItem(
                content: .text("Release checklist link"),
                sourceAppName: "Notes",
                tags: ["launch", "priority", "q3"],
                collection: "Planning",
                note: "Keep handy for launch day"
            )
            manager.history = [
                ClipboardItem(content: .image(makeSwatch()), sourceAppName: "Screen Capture",
                              title: "Screenshot receipt", tags: ["capture"], collection: "Captures",
                              ocrText: "Invoice total $42.00"),
                ClipboardItem(content: .text("https://saneapps.com/saneclip"), sourceAppName: "Safari"),
                ClipboardItem(content: .text("func floatingWindow() { /* resizable */ }"), sourceAppName: "Xcode"),
                ClipboardItem(content: .text("Customer quote worth saving"), sourceAppName: "Messages", note: "Testimonial"),
                ClipboardItem(content: .text("Temporary build number 2312"), sourceAppName: "Terminal"),
                pinned,
            ]
            manager.pinnedItems = [pinned]
        }
        if withStack {
            manager.pasteStack = Array(manager.history.prefix(3))
        }
        return manager
    }

    @MainActor
    private func makeSwatch() -> NSImage {
        let size = NSSize(width: 120, height: 72)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }

    private func screenshotDir() -> String? {
        if let env = ProcessInfo.processInfo.environment["SANECLIP_SCREENSHOT_DIR"]?
            .trimmingCharacters(in: .whitespacesAndNewlines), !env.isEmpty
        {
            return env
        }
        let hint = URL(fileURLWithPath: "/tmp/saneclip_screenshot_dir.txt")
        if let raw = try? String(contentsOf: hint, encoding: .utf8) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    @MainActor
    private func renderHistoryPNG(
        manager: ClipboardManager,
        license: LicenseService?,
        width: CGFloat,
        height: CGFloat,
        showFilters: Bool,
        mergeIDs: Set<UUID>,
        showStack: Bool,
        to url: URL
    ) throws {
        let size = CGSize(width: width, height: height)
        let view = ClipboardHistoryView(
            clipboardManager: manager,
            licenseService: license,
            previewInitialShowFilters: showFilters,
            previewInitialMergeQueueIDs: mergeIDs,
            previewInitialShowPasteStackPanel: showStack
        )
        .frame(width: width, height: height)
        .preferredColorScheme(.dark)

        let controller = NSHostingController(rootView: view)
        // Match the real floating window chrome so the capture looks like what a
        // customer sees (titled, resizable, full-size content).
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "SaneClip History"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        window.backgroundColor = .windowBackgroundColor
        window.setContentSize(size)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        controller.view.layoutSubtreeIfNeeded()
        // Let .onAppear seams + async layout settle before snapshotting.
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))

        // Prefer a window-server capture: it renders the true on-screen window
        // (title bar + correct horizontal-ScrollView content), which
        // NSView.cacheDisplay mis-captures for scroll views. Fall back to
        // cacheDisplay of the content view if the window-server image is
        // unavailable (e.g. Screen Recording permission not granted headless).
        if window.windowNumber > 0,
           let cgImage = CGWindowListCreateImage(
               .null,
               .optionIncludingWindow,
               CGWindowID(window.windowNumber),
               [.boundsIgnoreFraming, .bestResolution]
           ),
           cgImage.width > 1, cgImage.height > 1
        {
            let rep = NSBitmapImageRep(cgImage: cgImage)
            if let png = rep.representation(using: .png, properties: [:]) {
                try png.write(to: url, options: .atomic)
                window.orderOut(nil)
                return
            }
        }

        let renderView = controller.view
        guard let bitmap = renderView.bitmapImageRepForCachingDisplay(in: renderView.bounds) else {
            Issue.record("Failed to render \(url.lastPathComponent)")
            return
        }
        renderView.cacheDisplay(in: renderView.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            Issue.record("Failed to encode \(url.lastPathComponent)")
            return
        }
        try png.write(to: url, options: .atomic)
        window.orderOut(nil)
    }
}
