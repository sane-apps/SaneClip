# Session Handoff - SaneClip

Active handoff only. Older capture/App Store/pricing notes were compacted on
2026-05-21 to keep startup context small. Durable history remains in git,
`CHANGELOG.md`, `ARCHITECTURE.md`, Serena memory, and the knowledge graph.

## Current State

- Current release candidate: `2.3.7` / build `2307`.
- Current live direct/Lemon Squeezy version before release: `2.3.6`.
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
- SaneClip `2.3.6` direct channels are live: R2/appcast/site/Homebrew/email
  Worker were synced during the release run, and Lemon Squeezy hosted files now
  show exactly one published SaneClip file: `SaneClip-2.3.6.zip`.
- Mac App Store `2.3.6` was uploaded and submitted on 2026-05-21. ASC build
  `2306` processed successfully and the macOS version is `WAITING_FOR_REVIEW`.
- Local repo is clean except the intentionally restored unrelated
  `.outreach.yml` change from before the release.
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

## Verification Receipts

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
- App Store package export passed, package preflight passed, upload completed,
  build `2306` processed, screenshots uploaded, metadata synced, IAP readiness
  passed, and ASC returned `Successfully submitted for review`.
- Lemon Squeezy hosted-file audit at `2026-05-21T20:03:24Z` returned
  `current_actions: []`; SaneBar, SaneClick, SaneClip, SaneHosts, and SaneSales
  all show `In sync`.

## Next

1. Show exact customer/GitHub reply drafts and wait for approval before posting.
2. Check GitHub/App Store status later; SaneClip macOS `2.3.6` is submitted but
   not yet approved.
3. Leave `.outreach.yml` alone unless the user explicitly asks to handle launch
   calendar/outreach changes.
