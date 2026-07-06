import AppKit
import CoreGraphics
import Foundation
@testable import SaneClip
import SaneUI
import SwiftUI
import Testing

/// Visual-receipt renders for the history window across the real customer
/// window sizes and states. Split out of `HistoryWindowTests` to keep every
/// test file small and cohesive — the logic and assertions are unchanged.
struct HistoryRenderTests {
    private func projectRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
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
            .init(name: "13-pro-popover-merge-stack-320x500", width: 320, height: 500, pro: true, mergeActive: true, showStack: true),
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
    @Test("Render Glenn 1012 and 1013 regression proof screenshots when requested")
    func renderGlenn1012And1013ProofScreenshots() throws {
        guard let rawDir = screenshotDir() else { return }
        let outputDir = URL(
            fileURLWithPath: NSString(string: rawDir).expandingTildeInPath,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let proLicense = makeForcedProLicense()
        let queuedManager = ClipboardManager(startMonitoring: false, loadPersistedState: false, persistenceEnabled: false)
        queuedManager.history = [
            ClipboardItem(content: .text("Glenn merge queue item 1"), sourceAppName: "Safari"),
            ClipboardItem(content: .text("Glenn merge queue item 2"), sourceAppName: "Notes"),
            ClipboardItem(content: .text("Glenn merge queue item 3"), sourceAppName: "TextEdit"),
        ]
        queuedManager.mergeQueueIDs = Set(queuedManager.history.map(\.id))

        try renderHistoryPNG(
            manager: queuedManager,
            license: proLicense,
            width: 411,
            height: 718,
            showFilters: false,
            mergeIDs: [],
            showStack: false,
            to: outputDir.appendingPathComponent("glenn-1012-floating-reopened-merge-queue-retains-3.png")
        )

        try renderHistoryPNG(
            manager: queuedManager,
            license: proLicense,
            width: 320,
            height: 500,
            showFilters: false,
            mergeIDs: [],
            showStack: false,
            to: outputDir.appendingPathComponent("glenn-1012-fixed-switch-merge-queue-retains-3.png")
        )

        let settings = SettingsModel.shared
        let originalKeepOpen = settings.keepPasteStackOpenBetweenPastes
        settings.keepPasteStackOpenBetweenPastes = true
        defer { settings.keepPasteStackOpenBetweenPastes = originalKeepOpen }
        try renderHistoryPNG(
            manager: makeManager(seed: .rich, withStack: false),
            license: proLicense,
            width: 411,
            height: 718,
            showFilters: false,
            mergeIDs: [],
            showStack: false,
            to: outputDir.appendingPathComponent("glenn-1012-keep-open-pin-visible-before-paste.png")
        )

        let pausedManager = makeManager(seed: .rich, withStack: false)
        pausedManager.pauseCapture(minutes: 5)
        try renderHistoryPNG(
            manager: pausedManager,
            license: proLicense,
            width: 411,
            height: 718,
            showFilters: false,
            mergeIDs: [],
            showStack: false,
            to: outputDir.appendingPathComponent("glenn-1013-pause-countdown-visible-while-idle.png")
        )

        for filename in [
            "glenn-1012-floating-reopened-merge-queue-retains-3.png",
            "glenn-1012-fixed-switch-merge-queue-retains-3.png",
            "glenn-1012-keep-open-pin-visible-before-paste.png",
            "glenn-1013-pause-countdown-visible-while-idle.png",
        ] {
            #expect(FileManager.default.fileExists(atPath: outputDir.appendingPathComponent(filename).path))
        }
    }

    @MainActor
    @Test("Render Glenn 1016 narrow hover metadata proof screenshot when requested")
    func renderGlenn1016NarrowHoverMetadataProof() throws {
        guard let rawDir = screenshotDir() else { return }
        let outputDir = URL(
            fileURLWithPath: NSString(string: rawDir).expandingTildeInPath,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let longSourceItem = ClipboardItem(
            content: .text("Screenshot received: narrow hover row pressure sample"),
            sourceAppName: "Equifax GC Ban extension",
            pasteCount: 1,
            title: "Screenshot received",
            tags: ["launch", "priority", "q3"],
            collection: "Planning"
        )
        let view = VStack(alignment: .leading, spacing: 8) {
            Text("300 pt hover row")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))

            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.clipBlue)
                    .frame(width: 4)
                VStack(alignment: .leading, spacing: 6) {
                    Text(longSourceItem.title ?? longSourceItem.preview)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(.white)
                    Text(longSourceItem.preview)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundStyle(.white.opacity(0.9))
                    HStack(spacing: 4) {
                        ForEach(longSourceItem.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.clipBlue.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    ClipboardItemRowMetadata(
                        item: longSourceItem,
                        accentColor: .clipBlue,
                        showsDragAffordance: true,
                        shortcutHint: "⌘⌃1",
                        onPreviewImage: {}
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(9)
            .frame(width: 300, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.35)))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.clipBlue.opacity(0.45), lineWidth: 1)
            )
        }
        .padding(12)
        .background(Color(red: 0.08, green: 0.08, blue: 0.09))
        .preferredColorScheme(.dark)

        let url = outputDir.appendingPathComponent("glenn-1016-narrow-hover-metadata-adaptive.png")
        try renderViewPNG(view, size: CGSize(width: 324, height: 158), to: url)
        #expect(FileManager.default.fileExists(atPath: url.path))
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

    @MainActor
    private func renderViewPNG<V: View>(_ view: V, size: CGSize, to url: URL) throws {
        let controller = NSHostingController(rootView: view.frame(width: size.width, height: size.height))
        controller.view.frame = NSRect(origin: .zero, size: size)
        controller.view.layoutSubtreeIfNeeded()

        guard let bitmap = controller.view.bitmapImageRepForCachingDisplay(in: controller.view.bounds) else {
            Issue.record("Failed to render \(url.lastPathComponent)")
            return
        }
        controller.view.cacheDisplay(in: controller.view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            Issue.record("Failed to encode \(url.lastPathComponent)")
            return
        }
        try png.write(to: url, options: .atomic)
    }
}
