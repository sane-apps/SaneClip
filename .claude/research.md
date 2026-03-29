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
- Local Setapp skeleton is now verified farther than planning:
  - `SaneClipSetapp` scheme builds locally
  - widget bundle id is `com.saneclip.app-setapp.widgets`
  - raw build output can still re-embed `Sparkle.framework` and restore `SU*` keys after target shell phases
  - authoritative cleanup now uses `/Users/sj/SaneApps/infra/SaneProcess/scripts/sanitize_distribution_bundle.rb --channel setapp <app>`
  - after sanitation and ad hoc re-sign, the Setapp bundle launches locally and stays running
- Direct SaneClip still passes local `./scripts/SaneMaster.rb verify --quiet` with `108` tests after the Setapp scaffolding changes.
- Remaining real blockers before a true Setapp-ready claim:
  - `setappPublicKey.pem`
  - Setapp-specific release/update resources
  - explicit final signing flow after sanitation
  - mini-side verification once `ssh mini` is back

## Setapp Mini Verification
**Updated:** 2026-03-18 00:18 ET | **Status:** mini bundle verification good; signed Setapp release still blocked | **TTL:** 14d
**Source:** clean mini worktree builds, mini bundle inspection, mini launch checks, mini signed-build log, official Setapp docs
- Clean mini worktree for SaneClip was updated to commit `715b8cd`.
- `SaneClipSetapp` now builds on the mini with:
  - bundle id `com.saneclip.app-setapp`
  - widget bundle id `com.saneclip.app-setapp.widgets`
  - no embedded `Sparkle.framework`
  - `NSUpdateSecurityPolicy` for `com.setapp.DesktopClient.SetappAgent`
  - `MPSupportedArchitectures = [arm64]`
- The Setapp build script now expects the real Setapp key at `Setapp/setappPublicKey.pem` and warns if it is missing.
- `SaneClipSetapp.entitlements` now adds `com.setapp.ProvisioningService` for the sandboxed Setapp lane.
- After sanitize + plain ad hoc re-sign, the mini-launched Setapp bundle runs and `lsappinfo` reports `CFBundleIdentifier = com.saneclip.app-setapp`.
- A real signed mini build still fails before launch because Xcode requires a provisioning profile with the iCloud capability for `SaneClip` and a provisioning profile for `SaneClipWidgets`.
- So the current blocker is no longer “Setapp lane not scaffolded”; it is “real Setapp credentials/provisioning and final signing are still missing.”

## Settings Contrast + Menu Bar Icon Research
**Updated:** 2026-03-23 | **Status:** verified | **TTL:** 21d
**Source:** local code + SaneBar reference + Apple docs + GitHub/Web
- Local root cause: `UI/Settings/SettingsView.swift` had many small `.caption` labels, weak `.secondary` text, and plain `.bordered` buttons in the settings/about flow. That made SaneClip read materially weaker than the current SaneBar SaneUI standard.
- Local root cause: `SaneClipApp.swift` was assigning `NSImage(systemSymbolName:)` directly to the status item button without marking the image as a template, so the system never got to render the symbol in the normal menu-bar color.
- Local reference standard: SaneBar already uses `SaneUI.SaneActionButtonStyle`, stronger white copy, and template-rendered menu bar icons. That is the correct in-house baseline for SaneClip too.
- Apple docs: on current macOS, single-window screenshots should use `ScreenCaptureKit` (`SCScreenshotManager.captureImage`, `SCContentFilter(desktopIndependentWindow:)`) instead of deprecated `CGWindowListCreateImage`.
- Apple docs + platform behavior: menu bar/status item glyphs should use template rendering so macOS can choose the correct light/dark menu bar color automatically.
- GitHub/Web competitor pattern: mature menu bar apps and our own SaneBar code mark menu bar symbols/images as template images and avoid hard-coded menu bar icon colors.

## App Store Advertising Readiness
**Updated:** 2026-03-27 | **Status:** verified | **TTL:** 7d
**Source:** live public App Store page + GitHub issue audit + inbox audit + Mini verification
- The live public App Store page for `id6758898132` currently presents SaneClip as `Free · In-App Purchases` with iPhone/iPad-focused copy about synced clipboard history, widgets, Share Sheet saving, pinning, and private iCloud sync.
- That public copy does not currently contain the older false Mac/App Review messaging about external checkout, demo-only free mode, or nonexistent settings paths.
- The public iOS App Store description is materially accurate against the shipped code: search, pinning, widgets, Share Sheet saving, iCloud sync, and Pro-only encryption/advanced workflows are all real features.
- Pinning is still Pro-gated on macOS, but it is free on iPhone/iPad in the live code, so the current public iOS-facing App Store copy is not lying when it mentions pinning in the included experience.
- Current live customer pressure is low: the inbox has no open SaneClip email threads, GitHub has one open issue (`#3`), and `check-inbox.sh issue-review SaneClip 3` classifies it as waiting for reporter confirmation rather than a newly reproducing live regression.
- The remaining open GitHub issue is specifically the stale iPhone sync thread from before iOS `2.2.6` went live; there has been no reporter follow-up since 2026-03-11 after the maintainer said the iPhone fix was pending App Review.
- Mini verification on 2026-03-27 passed for the current repo state: `./scripts/SaneMaster.rb verify` passed with 112 tests, `./scripts/SaneMaster.rb test_mode --release --no-logs` launched the fresh signed release app successfully, and the iOS Release target built cleanly with `xcodebuild ... -scheme SaneClipIOS -configuration Release -destination generic/platform=iOS build CODE_SIGNING_ALLOWED=NO`.
- Current go/no-go interpretation: SaneClip looks safe enough to advertise this week, but the stale open GitHub sync thread should be followed up for a fresh retest rather than ignored indefinitely.
- Practical rule going forward: if a settings/about surface uses SaneUI chrome elsewhere, do not regress to `.caption`, `.secondary`, and default bordered buttons for primary actions or explanatory copy.

## Sync Status Gate Refresh
**Updated:** 2026-03-28 | **Status:** verified | **TTL:** 7d
**Source:** Apple CloudKit docs + web competitor docs + GitHub issue #3 + local code/tests
- Apple CloudKit docs still confirm the core production rule: App Store builds can only use the production environment, and record types/fields must be deployed from development to production before shipping. That matches SaneClip's earlier real production-schema failure.
- Apple CloudKit docs still support the current app architecture: development can be reset independently, but production schema changes are additive, which fits SaneClip's custom-zone `CKSyncEngine` model instead of a destructive migration story.
- Current public competitor positioning still supports SaneClip's local-first sync framing. Paste explicitly says clipboard data stays on-device and in the user's private iCloud, while Raycast's public Cloud Sync docs still treat clipboard history as sensitive. The right product claim remains optional private iCloud sync, not server-based sync.
- GitHub issue `#3` is still the only active public sync thread. The latest reporter update says macOS looks better, but iPhone sync still under-syncs (`151` items on Mac, only `19` on iPhone after restarts). That means the issue is not cleanly closed yet even though the earlier Mac-side bootstrap failure narrowed.
- Local code still shows the intended protections are present in `Core/Sync/SyncCoordinator.swift`: persisted `CKSyncEngine.State.Serialization`, explicit custom zone creation, initial local seed tracking via `syncInitialLocalSeedPending`, and remote-deletion blocking while the seed is pending.
- Local tests still cover the current sync safety story: bootstrap seeding, pending-record filtering, remote-deletion blocking while the initial seed is pending, and failure diagnostics are all present in `Tests/SaneClipTests.swift`.
- Practical rule for this pass: settings/About standardization work should not alter sync behavior, claims, or troubleshooting copy unless the code and public thread both support it.
