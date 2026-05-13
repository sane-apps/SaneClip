# Research Cache

> Active research index only. Durable CloudKit, Setapp, Sparkle, and Basic/Pro
> findings were promoted to Serena/memory on 2026-05-04. Older raw notes remain
> recoverable in git history.

## SaneUI Login Item API Migration | Updated: 2026-05-09 | Status: verified | TTL: 30d
- Trigger: SaneClip verify failed after moving to current SaneUI because `SaneLoginItemPolicy.enableByDefaultIfNeeded` no longer exists.
- Local source of truth: `~/SaneApps/infra/SaneUI/Sources/SaneUI/Components/SaneLoginItemToggle.swift` exposes `scheduleDefaultLaunchAtLoginPrompt(appName:delay:)`, `offerDefaultLaunchAtLoginIfNeeded(...)`, `setEnabled(...)`, and `shouldOfferDefaultPrompt(...)`.
- Decision: apps should not silently auto-enable login items. For launch-time default behavior, call `SaneLoginItemPolicy.scheduleDefaultLaunchAtLoginPrompt(appName:)`; the shared policy gates by install location, prior prompt marker, default setting, and current `SMAppService` status.
- SaneClip tests already encode this migration by expecting `scheduleDefaultLaunchAtLoginPrompt(appName: "SaneClip"` and rejecting `enableByDefaultIfNeeded`.

## SaneClip Editor Shortcuts / Text Input | Updated: 2026-05-12 | Status: verified | TTL: 30d
- Trigger: GitHub issue #10 reported the Show Clipboard History shortcut not working; issue #9 reported edit-sheet save/close trouble in SaneClip 2.3.0. Both remain open only for reporter confirmation after the 2.3.3 replies; no new reporter evidence has changed the root cause.
- Apple SwiftUI `KeyboardShortcut` docs still define `.defaultAction` as Return for default buttons and `.cancelAction` as Escape for cancellation/dismissal. Apple `onDeleteCommand` docs list focused command handlers including `onMoveCommand`, `onDeleteCommand`, and `onCommand`, so list navigation/delete handling should stay focus-scoped instead of being handled by global key interception.
- KeyboardShortcuts upstream remains the right package for user-customizable global shortcuts on macOS; the current README describes the package as global, sandboxed, and Mac App Store compatible, with shortcut values stored through the package's recorder/UserDefaults flow.
- GitHub evidence: `sane-apps/SaneClip#9` is the stuck edit window/save/close report from 2.3.0; `#10` is the Show Clipboard History shortcut report from 2.3.0. Current public comments ask the reporter to retest 2.3.3; do not close without confirmation.
- Local code check: `KeyboardShortcuts.onKeyUp(for: .showClipboardHistory)`, `.captureScreenshot`, and `.captureText` are still the global shortcut registration path; Settings exposes recorders plus a visible reset button that restores Show Clipboard History to Command-Shift-Control-Y.
- Local code check: edit-sheet save is still centralized in `ClipboardItemRow.saveEditSheet()` and calls `clipboardManager.updateItem(...)` once, avoiding independent content/title/tags/collection/note mutations while the sheet is closing.
- Local code check: `ClipboardHistoryView` keeps text-input/sheet guards around row command shortcuts, while focused delete/move handling stays on SwiftUI command handlers; this preserves text editing rather than stealing keystrokes from text fields.
- Decision: no raw key-event interception for edit sheets or text inputs. Use explicit `.defaultAction`/`.cancelAction` buttons for modal save/cancel, `KeyboardShortcuts` for user-customizable global app shortcuts, and SwiftUI focused command handlers for list navigation/deletion.
- Verification expectation: after any shortcut/editor change, Mini verify must exercise the reset/default shortcut source tests, edit-sheet batch-update test, and customer UI action contract before release.

## Mac Basic vs Pro Gating Audit | Updated: 2026-04-20 | Status: active | TTL: 30d
- Keep active until 2026-05-20.
- Decision: Basic/Pro boundaries must stay visually clear and match onboarding, website, App Store, and in-app upgrade surfaces.
- Promotion target: ARCHITECTURE once the current gating review is fully closed.

## Shared Upsell Popup Dismissal | Updated: 2026-04-20 | Status: needs refresh | TTL: 14d
- Expired 2026-05-04.
- Refresh or promote before using this as implementation evidence.

## CKSyncEngine / CloudKit Ground Truth | Updated: 2026-05-04 | Status: promoted | TTL: 90d
- CKSyncEngine and production-schema rules were promoted to Serena/memory.
- Refresh from Apple docs before changing CloudKit behavior.

## Sparkle / Setapp Distribution Lanes | Updated: 2026-05-04 | Status: promoted | TTL: 90d
- Sparkle sandbox installer-launcher requirements and Setapp lane rules were promoted to Serena/memory.
- Treat old March Setapp notes as historical unless current release work references them.

## App Store History Popover Placement | Updated: 2026-04-20 | Status: expired | TTL: 7d
- Expired 2026-04-27.
- Reopen only with fresh App Store review or UI evidence.
