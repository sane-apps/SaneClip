# Session Handoff - SaneClip

Active handoff only. Older capture/App Store/pricing notes were compacted on
2026-05-21 to keep startup context small. Durable history remains in git,
`CHANGELOG.md`, `ARCHITECTURE.md`, Serena memory, and the knowledge graph.

## Current State

- Current released version: `2.3.9` / build `2309`.
- Direct Mac channel `2.3.9` is live on R2, Sparkle appcast, website,
  Homebrew, GitHub release, and email webhook. Verified live URL:
  `https://dist.saneclip.com/updates/SaneClip-2.3.9.zip`.
- App Store `2.3.9` is submitted for both platforms as of
  2026-06-06 17:07 EDT:
  `macos: 2.3.9 (WAITING_FOR_REVIEW) | ios: 2.3.9 (WAITING_FOR_REVIEW)`.
- Setapp `2.3.9` build `2309` is attached to Setapp app `1847`, version
  `46886`, for review. Uploaded archive:
  `outputs/SaneClip-Setapp-2.3.9.zip`; SHA256
  `89149b0da3917d9f007b977a0c9518b5fdebfa73941d8ed1a540417045787d4f`;
  portal archive URL:
  `https://store.setapp.com/app/1847/46886/app-1780778500-6a248604359f1.zip`.
- Release commits pushed: `b412aa6` (2.3.9 fixes), `8d8f1c5` (version tag
  `v2.3.9`), `6a9e206` (site links), `52d8a22` (release metadata).
- GitHub issue `sane-apps/SaneClip#14` was commented and closed as shipped in
  `2.3.9` on 2026-06-06.
- Full release verification on 2026-06-06 passed:
  `./scripts/SaneMaster.rb verify` green with `166` tests, customer UI sweep
  passed, `release_preflight` passed with warnings only, `appstore_preflight`
  passed with zero issues, direct ZIP HTTP 200, appcast propagation verified,
  Homebrew cask verified, email webhook verified, and strict post-release
  checks passed.
- Lemon Squeezy hosted paid files are in sync as of 2026-06-06 17:57 EDT.
  Dashboard uploads were updated for SaneBar `2.1.66`, SaneClip `2.3.9`, and
  SaneHosts `1.1.16`; the live hosted-file tracker reports `Current actions: 0`
  and the local upload folder reports `stale: 0`, `missing latest: 0`,
  `unexpected: 0`. Evidence:
  `outputs/hosted_file_actions_20260606_synced.md`.
- 2026-06-06 GitHub `#14` / menu-bar visibility fix:
  - Added a Mac setting in General > Appearance: `Show menu bar icon`.
  - The menu bar item visibility updates live via `statusItem.isVisible`; hiding
    it closes any open popover.
  - Entry-point invariant is enforced both ways: hiding the menu bar icon forces
    Dock visibility on, and hiding Dock while the menu bar icon is hidden forces
    the menu bar icon back on.
  - Launch recovery now repairs a bad persisted state where both are false by
    restoring Dock visibility and writing `showInDock=true` back to defaults.
  - Verification: `./scripts/SaneMaster.rb verify` passed with `164` tests on
    2026-06-06 after the invariant fix.
  - Visual verification: screenshot-enabled `./scripts/SaneMaster.rb verify`
    passed with `164` tests using the test harness hint file, producing
    `outputs/visual-qa-20260606-menu-dock/settings-general-render.png`.
    Inspected render: the new toggle is readable, aligned, and well placed in
    Appearance above the menu bar icon picker with no visible overlap/clipping.
  - Customer UI QA was refreshed after the settings change:
    `ruby scripts/customer_ui_action_sweep.rb --json` passed with transcript
    `outputs/customer-ui/sweep-20260606T195918Z/customer-action-runtime.log`.
  - `./scripts/SaneMaster.rb release_preflight` passed after the refreshed UI
    receipt with warnings only: 12 uncommitted files, UserDefaults/migration
    change warning, appcast/Homebrew still live at `2.3.8` before publish, 1
    open GitHub issue, and 6 pending emails.
- 2026-06-06 Setapp review remediation:
  - Support triage found Setapp/MacPaw email #816 was not a resolvable duplicate;
    it needs a substantive security-response reply before #798/#799/#800 can be
    cleaned up as related no-reply Setapp notifications.
  - SaneClip Setapp entitlement cleanup is applied for local `2.3.9` build
    `2309`:
    removed the unnecessary Apple Events entitlement and old Sparkle
    `$(PRODUCT_BUNDLE_IDENTIFIER)-spki` / `-spks` mach-lookup placeholders from
    `SaneClip/SaneClipSetapp.entitlements`, leaving only
    `com.setapp.ProvisioningService`.
  - Setapp build script now deletes the unused
    `NSAppleEventsUsageDescription` from the built Info.plist while continuing
    to strip Sparkle framework/direct-store update keys.
  - Setapp provisioning was fixed on 2026-06-06 by enabling CloudKit/iCloud
    container `iCloud.com.saneclip.app` on bundle ID
    `com.saneclip.app-setapp` in Apple Developer, regenerating Developer ID
    profile `SaneClip Setapp Developer ID 2309`, and installing it on the Mini.
  - Setapp archive validation passed: deep signature valid, CloudKit/app-group
    entitlements present, `setappPublicKey.pem` bundled, 1024/512 icon
    representations present, forbidden App Store/Sparkle keys stripped, and
    Sparkle remains weak-linked only.
  - Setapp upload succeeded through portal fallback because the official CI
    upload token is not configured. Archive is attached to app `1847`, version
    `46886`, for review.
  - Draft security response for email #816 was updated to mention SaneClip
    `2.3.9` build `2309` and passed `reconcile`/`verify-facts`; do not send
    until the final release/submission status is accurate and explicit approval
    is recorded with `check-inbox.sh approve`.
- 2026-06-06 iOS publish fix:
  - First `2.3.8` release run submitted macOS successfully, then iOS archive
    failed because shared `SyncCoordinator.swift` referenced macOS-only
    `SettingsModel.shared.encryptHistory`.
  - Fixed by moving sync encryption decision to the shared `encryptHistory`
    UserDefaults key via `SyncCoordinator.encryptHistoryKey` and adding source
    regression guards.
  - Verification passed after the fix: `./scripts/SaneMaster.rb verify` green
    with `160` tests; fresh customer UI sweep passed with receipt timestamp
    `2026-06-06T19:19:48Z`.
  - Retried the iOS-only App Store lane: archive succeeded, IPA export
    succeeded, build `2308` processed successfully, screenshots/metadata/IAP
    passed, and iOS version `2.3.8` reached `WAITING_FOR_REVIEW`.
- 2026-06-06 Lemon Squeezy hosted-file cleanup:
  - Updated SaneBar, SaneClip, and SaneHosts paid hosted files in the Lemon
    Squeezy dashboard using the saved Mini Safari login.
  - Verified via `./scripts/SaneMaster.rb hosted_file_actions --json-out
    outputs/hosted_file_actions_20260606_synced.json --evidence-out
    outputs/hosted_file_actions_20260606_synced.md`.
  - Final result: `Current actions: 0`; all five direct-download apps in the
    tracker are `In sync`.
- 2026-06-06 best-in-class audit / `2.3.8` staging:
  - Market/platform research was refreshed in `.claude/research.md`. Conclusion:
    SaneClip should be positioned as Mac-first automatic capture plus
    iPhone/iPad companion flows. Do not promise impossible iOS background
    clipboard-history parity.
  - Parallel audit lanes covered website/docs, signing/privacy, support,
    tooling, and runtime resources. Fixed confirmed blockers: homepage
    webhook/web-integration overclaim, contradictory "no telemetry" public
    copy, Mac-only support FAQ for iPhone users, iOS CloudKit upload encryption
    hard-coded plaintext path, and share-extension image activation metadata.
  - `project.yml`/`SaneClip.xcodeproj` now declare
    `NSExtensionActivationSupportsImageWithMaxCount: 1` for the iOS share
    extension.
  - Sync upload tests now guard that iOS CloudKit records do not hard-code
    `encrypt: false`; `SyncDataModel` encrypted CloudKit record round-trip is
    covered by tests.
  - Verification passed after the version bump:
    `./scripts/SaneMaster.rb verify` green with `160` tests.
  - Customer UI QA refreshed after the version bump:
    `ruby scripts/customer_ui_action_sweep.rb --json` passed with transcript
    `outputs/customer-ui/sweep-20260606T184145Z/customer-action-runtime.log`;
    `./scripts/SaneMaster.rb customer_ui_contract --json --no-exit` passed with
    receipt timestamp `2026-06-06T18:41:45Z`.
  - `./scripts/SaneMaster.rb release_preflight` passed with warnings only:
    30 uncommitted files, appcast/Homebrew still at live `2.3.7` before publish,
    1 open enhancement issue, and 6 pending emails.
  - `./scripts/SaneMaster.rb appstore_preflight` passed with warning only:
    30 uncommitted files. ASC version lanes are clear:
    `macos: 2.3.8 clear | ios: 2.3.8 clear`.
  - Historical release blocker resolved on 2026-06-06: Lemon Squeezy hosted
    paid files were updated after the `2.3.9` release; see the current-state
    evidence entry above.
- 2026-06-06 post-audit remediation pass:
  - iPhone/iPad is now consistently framed as a companion, not Mac feature
    parity. Onboarding, empty states, website guides, README, Fastlane metadata,
    and release notes were updated around current-pasteboard limits, Share
    sheet import, foreground sync, and Mac-as-full-app boundaries.
  - The iOS History pending clipboard affordance is visible again and now has
    explicit save/dismiss actions. Visual verification passed on iPhone 17 Pro
    simulator for onboarding, History pending-card placement, and Settings Help.
  - Normal iOS users no longer receive demo history; demo data is restricted to
    screenshot mode.
  - Settings now exposes Support and Report a Bug, and the old explanatory
    Settings footer was removed after visual verification showed tab-bar
    overlap.
  - Privacy/security boundaries were tightened: Shortcuts/App Intents respect
    Touch ID history lock, widget previews are cleared while history lock is
    enabled, image assets are encrypted when history encryption is enabled, and
    iOS import/share paths skip high-risk sensitive text while allowing ordinary
    email/contact text.
  - Data-loss fixes: history export/import now round-trips through
    `SavedClipboardItem` with legacy export fallback; Paste Stack consumes only
    after pasteboard write succeeds; URL scheme copy no longer leaves
    self-write suppression stuck at `Int.max`; local edit/delete paths now queue
    supported sync updates/deletes, including iOS companion delete.
  - Share Extension waits for async item loads before completing and supports
    text, URL, and image saves through the shared app-group history container.
  - Public webhook claims were narrowed because webhook delivery is not exposed
    in Settings/runtime; public docs now advertise supported URL schemes,
    App Intents, and Shortcuts only.
  - QA receipt semantics corrected for sync/iOS external boundaries; refreshed
    customer UI receipt timestamp `2026-06-06T17:43:03Z`; contract passed with
    no issues.
  - Verification passed: `./scripts/SaneMaster.rb verify` green with `158`
    tests; iOS simulator `SaneClipIOS` build/run passed on iPhone 17 Pro
    (iOS 26.5). Remaining verify warnings are pre-existing:
    `Core/ClipboardManager.swift` parameter count and `Core/Sync/SyncCoordinator.swift`
    file length.
  - Historical external action resolved on 2026-06-06: Lemon Squeezy hosted
    files were updated and now pass the hosted-file tracker.
- 2026-06-04 `2.3.7` release-candidate proof:
  - iPhone/iPad companion foreground sync now starts from `ContentView` on
    launch/scene activation, refreshes every 8 seconds while foregrounded, and
    suppresses the local pasteboard save banner when iCloud sync is enabled so
    Mac-origin clips do not look like they require extra manual acceptance.
  - App Store and direct-release notes were updated for the foreground sync
    behavior; `project.yml` and regenerated `SaneClip.xcodeproj` are bumped to
    `2.3.7` / build `2307`.
  - Follow-up refactor pass moved menu/context-menu construction into
    `SaneClipAppDelegate+Menus.swift`; `SaneClipApp.swift` is now under the hard
    800-line split threshold. `GeneralSettingsView.swift` remains slightly over
    the 500-line attention threshold at 544 lines and should be split further in
    a later cleanup.
  - Mini `./scripts/SaneMaster.rb verify --timeout 900` passed with `150` tests.
  - Mini `./scripts/SaneMaster.rb customer_ui_sweep --json` passed with 12
    actions and receipt timestamp `2026-06-04T03:27:08Z` after updating the
    sweep source guards for the new split files.
- 2026-06-04 `2.3.7` final release/submission proof:
  - Direct release completed: notarized/stapled Mac zip
    `SaneClip-2.3.7.zip`, SHA-256
    `402ce8addf15b0396c9a158c537f521447c69118d955f6d5c8e4f4f56ba96892`,
    Sparkle signature
    `150eUUtx4gXWD6ozCH3QCuF3KSGZTNZ39niL+lsQF1KFLOBbQjAeDX9LNQJM18iQ41D+N6TH0ZW4OhaD6QFoAw==`.
  - Live direct URL verified `HTTP 200`:
    `https://dist.saneclip.com/updates/SaneClip-2.3.7.zip`, content length
    `3825199`.
  - Live appcast verified `2.3.7` with `sparkle:version="2307"`.
  - Homebrew tap updated to `2.3.7`.
  - Email webhook Worker updated/deployed for SaneClip bundle/download
    delivery; webhook tests passed `23/23`.
  - Final Mini verify passed `154` tests.
  - Final Mini customer UI sweep passed `12` actions with receipt timestamp
    `2026-06-04T04:24:52Z`.
  - Final `appstore_preflight` passed: `ALL CLEAR — ready for App Store
    submission`.
  - macOS App Store build `2307` uploaded, processed, attached to ASC version
    `2.3.7`, and submitted. ASC state:
    `platform=MAC_OS version=2.3.7 state=WAITING_FOR_REVIEW`,
    submission ID `f4f13e05-09bd-4e13-a776-4a814802dac9`.
  - iOS App Store build `2307` uploaded, processed, attached to ASC version
    `2.3.7`, and submitted. ASC state:
    `platform=IOS version=2.3.7 state=WAITING_FOR_REVIEW`,
    submission ID `e2b88dbd-3177-466b-beab-527367c3e6ee`.
  - IAP price schedule was accidentally created at `$6.99` by the helper
    default during the first macOS submit attempt, then immediately corrected
    with `--iap-price-usd 14.99`; both macOS submit-only and iOS submit
    verified USA `$14.99`.
  - Final `release_preflight` passed with warnings only: 1 open GitHub issue,
    3 pending customer emails, and night-release timing.
- 2026-06-04 settings/window refactor proof pass:
  - Split settings/window ownership without changing behavior:
    `SaneClipAppDelegate+HistoryWindow.swift` now owns history window/popover
    presentation, `SettingsWindowController.swift` owns the settings window, and
    `SettingsView.swift` was split into focused settings files for General,
    General actions, Excluded Apps, Shortcuts, and Clipboard Rules.
  - Added `SaneClipAppDelegate+HistoryWindow.swift` to both macOS app targets in
    `project.yml` and regenerated `SaneClip.xcodeproj` with XcodeGen.
  - Updated source-policy tests so popover anchoring and launcher/reopen history
    behavior read the extracted history-window file.
  - Mini verification passed after the split:
    `./scripts/SaneMaster.rb verify --timeout 900` passed `149` tests. A second
    screenshot-enabled verify using `/tmp/saneclip_screenshot_dir.txt` also
    passed `149` tests and rendered settings screenshots.
  - Mini runtime visual smoke passed:
    `outputs/visual-audit-20260604/visual_smoke_20260603-220115_80465/receipt.json`.
    SaneClip had no normal app window, so `app-see` was skipped by design for
    the menu-bar launch.
  - Clean rendered visual evidence copied locally under
    `outputs/visual-audit-20260604/rendered-settings/`; inspected
    `settings-general-render.png`, `settings-shortcuts-render.png`,
    `settings-license-render.png`, and `history-smart-clear-render.png`.
    The inspected renders had readable bright text and no visible overlap or
    clipping.
  - Fresh research cache entry added for the XcodeGen/root-source and
    cross-file access findings:
    `.claude/research.md` section `SaneClip Settings/Window Refactor Source Inclusion`.
- 2026-05-27 09:35 EDT cross-product launch ops reran canonical Mini
  `launch_readiness`; it exited `1`, so no launch, directory, or public-reply
  action was executed. The active blockers are still the `needs_dmca` piracy
  page, open GitHub issues `#9-#12` needing verified replies or explicit no-go
  status, App Store/iOS conversion surfaces needing a fresh check, the
  local-only 30-second video, Mini `release_preflight` carrying `4` warnings,
  and the shared validation report marking SaneClip customer UI proof stale and
  older than 12 hours. The same-day `2026-05-27 10:00 EDT` Clipboard/OCR
  decision slot had not opened yet at decision time, so it stayed pending
  rather than being marked complete early. No new public URL was created in
  this run.
- 2026-05-24 23:21 EDT webhook drift cleanup: sane-email-automation
  `PRODUCT_CONFIG` was updated and deployed so live SaneClip order/download
  emails now serve `SaneClip-2.3.6.zip`; live signed download snapshot verified
  file/version/domain and SaneClip `release_preflight` passed with warnings
  only.
- SaneClip `2.3.7` direct channels are live: R2/appcast/site/Homebrew/email
  Worker were synced during the release run.
- Mac App Store and iOS App Store `2.3.7` are both `WAITING_FOR_REVIEW`.
- Local and Mini repos were clean after submission checks.
- Open customer/public follow-up: GitHub `#13` should receive a user-approved
  reply saying 2.3.6 improves Protect Passwords for generated passwords copied
  from browser extensions.

## Release/Process Findings

- The stale ASC macOS `2.3.4` lane was still `WAITING_FOR_REVIEW`. It was
  withdrawn, became `DEVELOPER_REJECTED`, then repaired/retargeted to `2.3.6`
  before upload.
- SaneProcess was fixed so full release version-state checks call
  `appstore_submit.rb --repair-version-state --preflight-version-state`; test
  coverage now asserts repair runs before preflight.
- SaneProcess routed scratch cleanup and `.sanemaster/` ignore handling were
  fixed so routed release workspaces do not leave untracked scratch blockers.
- SaneClip App Store metadata was updated with explicit copyright,
  content-rights, export-compliance, and iOS accessibility declaration families.
- The strict customer UI receipt was refreshed on the Mini and now includes
  screenshot evidence for `snippets-management-actions`.
- SaneProcess routed release reconcile was fixed in
  `~/SaneApps/infra/SaneProcess` commit `cb934c4` so Air-origin releases trust
  the routed Mini workspace context instead of trying to reverse-SSH to
  `Stephans-MacBook-Air.local`.
- App Store archive/export from SSH hit `errSecInternalComponent` for widget
  codesign. Working path was: unlock/grant keychain partition access once, then
  run short archive/export scripts through `mini-gui-run.sh` so Xcode signs in
  the Mini GUI session. Avoid long inline `mini-gui-run.sh` commands; use a
  generated `build/*.sh` script to prevent Terminal command-injection stalls.
- The first macOS App Store archive made with `CODE_SIGN_STYLE=Automatic` and
  blank `CODE_SIGN_IDENTITY` dropped sandbox entitlements. Correct archive path
  is the normal `SaneClip-AppStore` scheme with `Release-AppStore`,
  `-destination generic/platform=macOS`, and the project-configured
  entitlements. Verify both app and widget package payloads contain
  `com.apple.security.app-sandbox` before upload.
- Apple returned transient `500` errors while reserving macOS screenshot upload
  slots during the first submit. A separate `--screenshots-only` retry succeeded
  before the submit-only run.

## Verification Receipts

- 2026-06-06 iPhone pending clipboard import fix: History now shows a visible
  pending clipboard save card in both empty and populated states when iOS
  reports new local pasteboard content. The save action imports every current
  `UIPasteboard.items` payload item it can read, dedupes text/images, clears
  pending state after user action, and suppresses self-write pending prompts
  after copying an existing clip. Documented the iOS limitation that separate
  overwritten copy operations cannot be reconstructed once SaneClip reactivates;
  only the latest/current pasteboard payload can be saved. Visual QA captured
  the forced DEBUG pending-card state at
  `outputs/visual-qa-20260606/iphone-pending-clipboard-card.jpg` and verified
  text fit, placement below the context banner/search area, and no overlap with
  the list or tab bar. Verification: `./scripts/SaneMaster.rb verify --timeout
  900` passed with 154 tests on 2026-06-06 after regenerating
  `SaneClip.xcodeproj`.
- 2026-06-03 iPhone no-extra-tap sync fix: the iOS companion now starts
  CloudKit foreground sync from `ContentView` on launch/scene activation,
  keeps an 8-second foreground refresh loop in `ClipboardHistoryViewModel`,
  and suppresses the local iPhone pasteboard banner while iCloud sync is
  enabled so Mac-origin clips do not look like they require pasteboard
  permission/acceptance. Mini `./scripts/SaneMaster.rb verify --timeout 900`
  passed with 150 tests, including `iPhone sync refreshes automatically while
  foregrounded`. Research cache entry added:
  `.claude/research.md` section
  `SaneClip iPhone Foreground Sync / Pasteboard Banner`.
- 2026-05-24 Basic/Pro visual recheck: Mini Basic visual smoke
  `visual_smoke_20260524-190622_22006` and Pro visual smoke
  `visual_smoke_20260524-190813_30579` were inspected. Basic correctly showed
  locked Pro actions; Pro showed unlocked Paste/Stack/Smart Clear actions.
  Mini `customer_ui_sweep --json` generated receipt
  `2026-05-24T23:10:09Z`, and strict customer UI contract passed with no
  issues or warnings.
- 2026-05-24 SaneClip `#14` reopen/launcher patch: `SaneClipAppDelegate.applicationShouldHandleReopen` now opens/brings forward the history window when the already-running app is relaunched by Alfred/Launch Services. Mini `./scripts/SaneMaster.rb verify --timeout 900` passed with `155` counted tests, including `Reopening the running app opens the history window`. The separate request to hide the menu bar item remains an enhancement and is not part of this narrow patch.
- Mini verify passed 154 tests during:
  - SaneClip password-protection fix pre-push.
  - App Store metadata/visual receipt fix pre-push.
  - Duplicate changelog cleanup pre-push.
  - The final release rerun before App Store package export.
- `customer_ui_sweep --json` passed in the routed workspace at
  `2026-05-21T19:54:33Z`.
- `appstore_preflight` passed in the routed workspace with one warning only:
  the generated customer UI receipt was locally dirty after the sweep.
- App Store package export passed, package preflight passed, uploads completed,
  build `2307` processed on both macOS and iOS, screenshots uploaded, metadata
  synced, IAP readiness passed at `$14.99`, and ASC returned
  `Successfully submitted for review` for both platforms.
- Lemon Squeezy hosted-file audit at `2026-05-21T20:03:24Z` returned
  `current_actions: []`; SaneBar, SaneClick, SaneClip, SaneHosts, and SaneSales
  all show `In sync`.

## Next

1. Show exact customer/GitHub reply drafts and wait for approval before posting.
2. Check GitHub/App Store status later; SaneClip macOS and iOS `2.3.7` are both
   submitted but not yet approved.
3. Leave `.outreach.yml` alone unless the user explicitly asks to handle launch
   calendar/outreach changes.
