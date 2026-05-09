# Research Cache

> Active research index only. Durable CloudKit, Setapp, Sparkle, and Basic/Pro
> findings were promoted to Serena/memory on 2026-05-04. Older raw notes remain
> recoverable in git history.

## SaneClip Editor Shortcuts / Text Input | Updated: 2026-05-09 | Status: verified | TTL: 30d
- Trigger: GitHub issue #10 reported the Show Clipboard History shortcut not working; issue #9 reported edit-sheet save/close trouble. Release guard `saneclip-editor-shortcuts` requires fresh local + docs + web/GitHub evidence before shipping more keyboard behavior.
- Apple SwiftUI docs confirm `.keyboardShortcut(.defaultAction)` is the standard Return shortcut for a default button and `.cancelAction` is Escape; these belong on explicit sheet buttons, not hidden global interceptors. Apple Input Events docs expose command handlers like `onMoveCommand`, `onDeleteCommand`, and `onCommand` for focused view command handling, so row navigation and text editing need separate gates.
- KeyboardShortcuts upstream remains the right package for user-customizable global shortcuts on macOS. Its README states app-specific shortcuts are outside its scope and should use `NSEvent.addLocalMonitorForEvents`, `NSMenuItem`, or SwiftUI `.keyboardShortcut`; its recorder stores shortcuts in `UserDefaults` and warns when a shortcut is already taken by the system or app menu.
- Local code check: `ClipboardHistoryView.shouldHandleShortcut(...)` already disables history-row command shortcuts while a sheet is attached or text input is active, and tests cover sheet/text-input/list-navigation cases. The 2026-05-09 fix keeps that boundary and adds a visible Reset button for Show Clipboard History so users can restore Cmd+Shift+V without editing defaults.
- Local code check: edit-sheet save now uses `ClipboardManager.updateItem(...)` as a single batch mutation for content/title/tags/collection/note. This avoids multiple independent saves while the sheet is closing and keeps history, pinned, and paste-stack mirrors synchronized.
- Decision: do not add raw key-event interception for edit sheets. Use visible buttons with `.defaultAction`/`.cancelAction`, keep global shortcut registration in `KeyboardShortcuts`, and preserve text-input guards around row command shortcuts. Promote to DEVELOPMENT if this shortcut boundary recurs after the 2.3.1 release.

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
