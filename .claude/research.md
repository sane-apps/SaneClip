# Research Cache

Persistent research findings for this project. Limit: 200 lines.
Graduate verified findings to ARCHITECTURE.md or DEVELOPMENT.md.

## iOS Extension Scope
**Updated:** 2026-02-07 | **Status:** verified | **TTL:** 30d
**Source:** Apple docs + GitHub + web
- App Intents are the best ROI extension path for SaneClip. They are low effort, automation-friendly, and expected by power users.
- App Intents must live in the app target, not an SPM package.
- A Share Extension is moderate effort and useful for "Save to SaneClip" flows, but it does not replace clipboard history.
- A custom keyboard is high effort, high maintenance, and privacy-sensitive because Full Access prompts create trust friction.
- Recommendation order: App Intents first, Share Extension second, custom keyboard last or never.

## Clipboard UX Upgrade Priorities
**Updated:** 2026-02-27 | **Status:** verified | **TTL:** 30d
**Source:** local code + Apple docs + web + GitHub
- Current SaneClip already has date/content filters, notes, snippets, paste stack, URL schemes, and App Intents.
- Highest-value missing controls are ignore-next-copy, timed pause, max capture size controls, tags/collections, saved presets, merge workflow, and exclusion presets.
- Apple pasteboard APIs support the current polling model and safe type filtering.
- Competitor baseline is simple capture controls plus lightweight organization, not heavy database complexity.

## CKSyncEngine Ground Truth
**Updated:** 2026-03-10 | **Status:** verified | **TTL:** 30d
**Source:** Apple docs + WWDC 2023 Session 10188 + local code
- CloudKit sync for shipping builds uses the production container, so production schema must already contain every record type the app saves.
- `CKSyncEngineDelegate` requires `handleEvent(_:syncEngine:)` and `nextRecordZoneChangeBatch(_:syncEngine:)`.
- Custom record zones are required for tracked sync flows like SaneClip clipboard history.
- `syncEngine.state.serialization` must be persisted and restored on launch.
- Local pending changes must exist before `nextRecordZoneChangeBatch` is asked for work.
- Re-entering `sendChanges()` from send callbacks is unsafe and caused a real SaneClip crash.

## SaneClip CloudKit Release Readiness
**Updated:** 2026-03-10 | **Status:** verified | **TTL:** 30d
**Source:** Apple docs + cktool CLI + GitHub issue #3 + Mini runtime + local code
- Official CloudKit management auth path is `xcrun cktool save-token --type management --method file`.
- `cktool` stores the management token as a file at `~/.config/cktool`, not a directory.
- SaneMaster now syncs that file from the Air to the Mini for routed `release_preflight`, `appstore_preflight`, and `release`.
- The live production blocker was real: production schema was missing `ClipboardItem`, so CloudKit rejected saves with `Cannot create new type ClipboardItem in production schema`.
- Development schema was validated and imported first, then production schema was promoted so `ClipboardItem` now exists in production.
- The Mini signed Release build no longer crashes in the sync bootstrap path because the reentrant `sendChanges()` resend was removed.
- iOS now stores full-fidelity local history for later seeding instead of persisting only widget previews.
- Strongest end-to-end proof: a signed Mini Release build uploaded a real clipboard item into the production private CloudKit zone and CloudKit returned that record on query.
- `syncInitialLocalSeedPending` now clears to `0` after launch and a real clipboard event on the Mini.
- `release_preflight` now passes with warnings only.
- `appstore_preflight` now passes with warnings only when run serially; the earlier build failure was a locked Xcode build database caused by overlapping builds, not a product issue.
- Remaining release warnings are operational, not product blockers: dirty worktree, Homebrew cask still at `2.2.5`, open issue follow-up, and pending customer email.

## Clipboard Sync Competitor Positioning
**Updated:** 2026-03-10 | **Status:** verified | **TTL:** 30d
**Source:** official product sites + app listings
- Paste treats cross-device clipboard sync as a premium headline feature.
- Raycast keeps clipboard history local-only and does not promise device-to-device sync.
- SaneClip should keep the local-first story primary and describe iCloud sync as optional between the user's own devices.
