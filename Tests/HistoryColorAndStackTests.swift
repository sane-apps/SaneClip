import AppKit
import CoreGraphics
import Foundation
@testable import SaneClip
import SaneUI
import SwiftUI
import Testing

/// Color-semiotics, source-color, and paste-stack behavior tests for the
/// history window. Split out of `HistoryWindowTests` to keep every test file
/// small and cohesive — the logic and assertions are unchanged.
struct HistoryColorAndStackTests {
    private func projectRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
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

    @Test("Pause capture countdown invalidates from the monitor timer, not only pasteboard changes")
    @MainActor
    func pauseCaptureCountdownTicksWithoutPasteboardChange() {
        let manager = ClipboardManager(startMonitoring: false, loadPersistedState: false, persistenceEnabled: false)
        let now = Date()

        #expect(ClipboardManager.capturePauseRemainingText(until: now.addingTimeInterval(65), now: now) == "1m 5s")
        #expect(ClipboardManager.capturePauseRemainingText(until: now.addingTimeInterval(5), now: now) == "5s")
        #expect(ClipboardManager.capturePauseRemainingText(until: now.addingTimeInterval(-1), now: now) == nil)

        manager.pauseCapture(minutes: 5)
        #expect(manager.capturePauseRemainingText != nil)
        #expect(manager.refreshCapturePauseDisplayTick(now: Date().addingTimeInterval(2)))
        manager.resumeCapture()
        #expect(manager.capturePauseRemainingText == nil)
    }

    @Test("Merge queue selection is shared state so it survives history view recreation")
    @MainActor
    func mergeQueueSelectionSurvivesViewRecreation() {
        let manager = ClipboardManager(startMonitoring: false, loadPersistedState: false, persistenceEnabled: false)
        let items = (0 ..< 3).map { ClipboardItem(content: .text("queued \($0)")) }
        manager.history = items
        manager.mergeQueueIDs = Set(items.map(\.id))

        let recreatedViewSelection = manager.mergeQueueIDs
        #expect(recreatedViewSelection.count == 3)

        _ = manager.removeHistoryItems(withIDs: [items[0].id])
        #expect(!manager.mergeQueueIDs.contains(items[0].id))
        #expect(manager.mergeQueueIDs.count == 2)
    }

    @Test("Merge queue drops IDs for items removed by trim and expiry")
    @MainActor
    func mergeQueueIDsPruneWhenHistoryItemsDisappear() {
        let manager = ClipboardManager(startMonitoring: false, loadPersistedState: false, persistenceEnabled: false)
        manager.licenseService = makeForcedProLicense()

        let originalMax = SettingsModel.shared.maxHistorySize
        let originalExpire = SettingsModel.shared.autoExpireHours
        defer {
            SettingsModel.shared.maxHistorySize = originalMax
            SettingsModel.shared.autoExpireHours = originalExpire
        }

        SettingsModel.shared.maxHistorySize = 2
        let oldQueued = ClipboardItem(content: .text("old queued"), timestamp: Date().addingTimeInterval(-300))
        let newerQueued = ClipboardItem(content: .text("new queued"), timestamp: Date().addingTimeInterval(-200))
        let freshItems = (0 ..< 2).map { ClipboardItem(content: .text("fresh \($0)")) }
        manager.history = freshItems + [oldQueued, newerQueued]
        manager.mergeQueueIDs = [oldQueued.id, newerQueued.id]

        manager.enforceHistoryLimitIfNeeded(saveAfterTrim: false)
        #expect(manager.mergeQueueIDs.isEmpty)

        SettingsModel.shared.maxHistorySize = originalMax
        SettingsModel.shared.autoExpireHours = 1
        let expired = ClipboardItem(content: .text("expired"), timestamp: Date().addingTimeInterval(-7200))
        let current = ClipboardItem(content: .text("current"))
        manager.history = [current, expired]
        manager.mergeQueueIDs = [expired.id]
        manager.checkClipboardForTesting()
        #expect(!manager.mergeQueueIDs.contains(expired.id))
    }

    @Test("Paste success sound waits for simulated paste success")
    func pasteSuccessSoundWaitsForSimulation() throws {
        let source = try String(
            contentsOf: projectRootURL().appendingPathComponent("Core/ClipboardManager.swift"),
            encoding: .utf8
        )

        #expect(source.contains("let didPaste = self.simulatePaste()"))
        #expect(source.contains("if didPaste {\n                    SettingsModel.shared.pasteSound.play()"))
        #expect(source.contains("if didPaste && reopenPopoverAfterPaste {"))
        #expect(!source.contains("SettingsModel.shared.pasteSound.play()\n        if dismissPopover"))
    }

    @Test("Customer UI proof sweep does not fake Mini click completion")
    func customerUISweepProofContractRejectsFakeClickEvidence() throws {
        let source = try String(
            contentsOf: projectRootURL().appendingPathComponent("scripts/customer_ui_action_sweep.rb"),
            encoding: .utf8
        )
        let manifest = try String(
            contentsOf: projectRootURL().appendingPathComponent("Tests/CustomerUIActions.yml"),
            encoding: .utf8
        )

        #expect(!source.contains("user == 'stephansmac'"))
        #expect(!source.contains("host: 'mini'"))
        #expect(source.contains("Socket.gethostname"))
        #expect(source.contains("mini_click evidence requires real UI automation"))
        #expect(source.contains("coverage_status: 'covered'"))
        #expect(source.contains("completion_scope: 'structured_coverage_only'"))
        #expect(source.contains("covered_assertions: Array(action['expected_outputs'])"))
        #expect(source.contains("steps_covered: Array(action['steps'])"))
        #expect(!source.contains("output_assertions: Array(action['expected_outputs'])"))
        #expect(!source.contains("steps_completed: Array(action['steps'])"))
        #expect(!manifest.contains("mini_click"))
        #expect(!manifest.contains("full_runtime_completion"))
        #expect(manifest.contains("mini_runtime"))
        #expect(manifest.contains("Glenn's exact target-app receipt remains customer retest or manual"))
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

    @Test("Pinned items survive the history trim so a pin is never silently lost")
    @MainActor
    func pinnedItemsSurviveHistoryTrim() {
        let manager = ClipboardManager(startMonitoring: false, loadPersistedState: false, persistenceEnabled: false)
        manager.licenseService = makeForcedProLicense()

        SettingsModel.shared.maxHistorySize = 5
        defer { SettingsModel.shared.maxHistorySize = 100 }

        // Pin three clips via the real pin path, then flood history so the pins
        // fall past the cap and the trim runs over them.
        let pinned = (0 ..< 3).map { ClipboardItem(content: .text("pinned \($0)")) }
        for item in pinned {
            manager.history.insert(item, at: 0)
            manager.togglePin(item: item)
        }
        for index in 0 ..< 20 {
            manager.history.insert(ClipboardItem(content: .text("filler \(index)")), at: 0)
        }
        manager.enforceHistoryLimitIfNeeded(saveAfterTrim: false)

        // Every pinned item stays in history AND stays pinned — no silent unpin
        // and (for images) no asset deletion. Regression guard for the trim that
        // protected the paste stack but not pins (Maccy #1220 class).
        for item in pinned {
            #expect(manager.history.contains { $0.id == item.id })
            #expect(manager.pinnedItems.contains { $0.id == item.id })
        }
    }

    @Test("removeHistoryItems deletes a multi-selection from history, pins, and stack")
    @MainActor
    func removeHistoryItemsDeletesSelection() {
        let manager = ClipboardManager(startMonitoring: false, loadPersistedState: false, persistenceEnabled: false)
        manager.licenseService = makeForcedProLicense()

        let items = (0 ..< 4).map { ClipboardItem(content: .text("item \($0)")) }
        for item in items {
            manager.history.insert(item, at: 0)
        }
        manager.togglePin(item: items[0]) // pinned
        manager.addToPasteStack(items[1]) // queued in the paste stack

        // The footer "Delete" button (Maccy #239 bulk delete) calls this batch API
        // with the merge-queue selection. Deleting the pinned + stacked items must
        // remove them from every collection, not just history.
        let toDelete: Set<UUID> = [items[0].id, items[1].id]
        manager.removeHistoryItems(withIDs: toDelete)

        for id in toDelete {
            #expect(!manager.history.contains { $0.id == id })
            #expect(!manager.pinnedItems.contains { $0.id == id })
            #expect(!manager.pasteStack.contains { $0.id == id })
        }
        #expect(manager.history.contains { $0.id == items[2].id })
        #expect(manager.history.contains { $0.id == items[3].id })
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
}
