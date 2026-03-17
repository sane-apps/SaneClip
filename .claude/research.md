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

## Sparkle Installer Launcher Requirements
**Updated:** 2026-03-10 | **Status:** verified | **TTL:** 30d
**Source:** Sparkle docs + Sparkle source + Apple docs + competitor code + local entitlements/build inspection
- For sandboxed direct-distribution Sparkle apps, `SUEnableInstallerLauncherService` must be enabled in Info.plist.
- Sandboxed Sparkle apps also need mach lookup exceptions for `$(PRODUCT_BUNDLE_IDENTIFIER)-spki` and `$(PRODUCT_BUNDLE_IDENTIFIER)-spks`.
- SaneClip's shipped direct build was sandboxed but missing those Sparkle installer-launcher requirements, which matches the exact customer error `An error occurred while launching the installer.` and Sparkle log `Failed to submit installer job`.
- Dev/ProdDebug updater testing was a blind spot because those builds use non-sandbox debug entitlements, so they do not exercise the same installer-launch path as the signed Release build.
- Sparkle's official sandboxing guide says the Installer XPC service is required for sandboxed apps and must be enabled with `SUEnableInstallerLauncherService = YES`.
- Sparkle's official sandboxing guide also requires `com.apple.security.temporary-exception.mach-lookup.global-name` entries for `$(PRODUCT_BUNDLE_IDENTIFIER)-spki` and `$(PRODUCT_BUNDLE_IDENTIFIER)-spks`.
- Sparkle's official sandboxing guide also warns that the standard archive/export workflow is the trusted way to re-sign Sparkle and its XPC services for sandboxed apps.
- Local `test_mode` Release builds are not enough proof for this updater lane; SaneClip hit `Failed to make auth right set`, `Failed copying system domain rights: -60005`, and `Failed to submit installer job` there even after adding the launcher service keys.
- The trusted end-to-end updater proof for sandboxed SaneClip must use an archived/exported release artifact as both the installed host and the offered update.
- Sparkle source confirms the exact user-facing failure mapping: installer launcher failures log `Failed to submit installer job`, while signature validation failures surface `The update is improperly signed and could not be validated`.
- Apple's Mach/XPC security docs reinforce that sandboxed IPC should use the intended XPC path and explicit entitlement allowances instead of ad-hoc Mach access.
- Competitor check: Maccy, another clipboard manager using Sparkle, ships both `SUEnableInstallerLauncherService` and the same `spki` / `spks` mach-lookup exceptions.

## Setapp Single-App Distribution Lane
**Updated:** 2026-03-17 | **Status:** verified | **TTL:** 30d
**Source:** Setapp email thread `#370`, official Setapp docs, local SaneClip/SaneUI audit, public Setapp framework interface
- Setapp is an additional macOS channel for SaneClip, not a reason to replace the direct Lemon Squeezy business.
- SaneClip should use the same explicit three-lane model as SaneBar: `direct`, `appStore`, and `setapp`.
- The Setapp build should remove Sparkle, direct licensing UI, and donate/sponsorship UI while keeping the rest of the app visually consistent.
- Current macOS project settings are `arm64` only, so Setapp universal-readiness is an explicit blocker.
- Setapp requires a separate `-setapp` bundle ID and a real `setappPublicKey.pem` resource before final runtime verification is possible.
- SaneClip is mechanically easier than SaneBar for Setapp because it is not a menu bar manager, but it has more bundle surfaces (widgets/extensions), so bundle-family drift must be checked deliberately.
- For the Setapp lane, launch-at-login should remain explicit user opt-in instead of being quietly treated as a channel-side default.
- SaneClip currently stores app data in `Application Support/SaneClip` but keys credentials off the bundle ID, so a direct build and a Setapp build would likely share settings/history data while keeping separate license state.
