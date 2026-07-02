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
            "useFloatingHistoryWindow": true
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

        // Resizable window + sane bounds (not infinite).
        #expect(historyWindowSource.contains(".resizable"))
        #expect(historyWindowSource.contains("contentMinSize"))
        #expect(historyWindowSource.contains("contentMaxSize"))
        // Remembers last size + position across launches.
        #expect(historyWindowSource.contains("setFrameAutosaveName(Self.historyWindowFrameAutosaveName)"))
        #expect(historyWindowSource.contains("ensureWindowOnScreen"))
        // Menu-bar trigger routes to the floating window when the setting is on.
        #expect(historyWindowSource.contains("if SettingsModel.shared.useFloatingHistoryWindow"))
        // Off-screen guard clamps the restored origin into the visible frame
        // (not just recover fully off-screen frames).
        #expect(historyWindowSource.contains("min(max(frame.origin.x"))
        // Setting is user-exposed (now in General → Appearance).
        #expect(settingsSource.contains("Open history as a resizable floating window"))
    }

    @Test("Sparkle check frequency resolves and normalizes intervals")
    func sparkleCheckFrequencyBehavior() {
        #expect(SaneSparkleCheckFrequency.resolve(updateCheckInterval: 60 * 60 * 24) == .daily)
        #expect(SaneSparkleCheckFrequency.resolve(updateCheckInterval: 60 * 60 * 24 * 7) == .weekly)
        #expect(SaneSparkleCheckFrequency.normalizedInterval(from: 60 * 60 * 6) == SaneSparkleCheckFrequency.daily.interval)
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

        // toggleHistoryWindow (⌘⇧⌃Y hotkey) must not open the window directly.
        #expect(historyWindowSource.contains("withHistoryAuth { [weak self] in self?.showHistoryWindow() }"))
        // Dock/Finder reopen must go through the same gate.
        #expect(appSource.contains("withHistoryAuth { [weak self] in self?.showHistoryWindow() }"))
        // The gate delegates its decision to the tested pure function.
        #expect(historyWindowSource.contains("historyAuthSatisfied("))
    }

    @Test("Paste from the floating window hands focus back before the synthetic paste")
    func floatingWindowPasteReturnsFocus() throws {
        let historyWindowSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("SaneClipAppDelegate+HistoryWindow.swift"),
            encoding: .utf8
        )
        let appSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("SaneClipApp.swift"),
            encoding: .utf8
        )
        // The dismiss handler hides the app so the synthesized Cmd+V lands on the
        // target app, not our floating panel.
        #expect(historyWindowSource.contains("func handleDismissForPaste()"))
        #expect(historyWindowSource.contains("NSApp.hide(nil)"))
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
        // Drag-out is gated to non-pinned rows; pinned rows keep List `.onMove`.
        #expect(rowSource.contains(".onDragOut(enabled: !isPinned) { dragItemProvider() }"))
        #expect(rowSource.contains("func onDragOut(enabled: Bool"))
        #expect(rowSource.contains("func dragItemProvider() -> NSItemProvider"))
    }

    @Test("Footer keeps item count and actions reachable at narrow widths")
    func footerAvoidsSquash() throws {
        let footerSource = try String(
            contentsOf: projectRootURL().appendingPathComponent("UI/History/HistoryFooterView.swift"),
            encoding: .utf8
        )
        // Item count + Settings + Smart Clear stay pinned; only the secondary
        // controls scroll (with an indicator) so nothing squashes or hides
        // silently.
        #expect(footerSource.contains("private var itemCountLabel"))
        #expect(footerSource.contains("private var secondaryControls"))
        #expect(footerSource.contains("ScrollView(.horizontal, showsIndicators: true)"))
        #expect(footerSource.contains("private var settingsButton"))
        #expect(footerSource.contains("private var smartClearButton"))
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

        enum Seed { case rich, empty, longText, colorful }
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
            .init(name: "11-colorful-sources-440x700", width: 440, height: 700, seed: .colorful)
        ]

        let proLicense = makeForcedProLicense()

        for scenario in scenarios {
            let manager = makeManager(seed: scenario.seed, withStack: scenario.showStack)
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
                "Discord", "Figma", "Xcode", "Spotify"
            ]
            manager.history = sources.map { name in
                ClipboardItem(content: .text("Clip from \(name)"), sourceAppName: name)
            }
            manager.pinnedItems = []
        case .longText:
            let long = String(repeating: "supercalifragilistic-unbreakable-token-", count: 8)
            manager.history = [
                ClipboardItem(content: .text(long), sourceAppName: "Safari"),
                ClipboardItem(content: .text("Short normal clip"), sourceAppName: "Notes")
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
                pinned
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
            .trimmingCharacters(in: .whitespacesAndNewlines), !env.isEmpty {
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
           cgImage.width > 1, cgImage.height > 1 {
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
