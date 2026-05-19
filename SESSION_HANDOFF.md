# Session Handoff — SaneClip

**Last updated:** 2026-05-18
**Current project version:** `2.3.4` (build `2304`)

## Current State

- 2026-05-17 App Store listing repair:
  - Generated valid macOS App Store screenshots at `docs/images/appstore-mac-*.png` and updated `.saneprocess` so the macOS lane no longer points at general docs screenshots with invalid Apple sizes.
  - Verified the new macOS screenshot set with `appstore_submit.rb --test-screenshots`; all six resize to Apple's `2880x1800` desktop target.
  - App Store Connect initially rejected screenshot replacement because macOS `2.3.4` was already `WAITING_FOR_REVIEW`. The macOS lane was withdrawn, screenshots uploaded, build `2304` reattached, metadata refreshed, and macOS `2.3.4` resubmitted. Final ASC state from the submit helper: `WAITING_FOR_REVIEW`.
  - Follow-up blocker: full `appstore_preflight` still reports the combined iOS lane as final-state `READY_FOR_SALE` for `2.3.4`; the next combined macOS+iOS App Store submission needs a version bump.

- 2026-05-15 reporting-route hardening:
  - Fixed the iOS settings reporter to pass `githubRepo: "SaneClip"` instead of `githubRepo: "sane-apps/SaneClip"`, which produced a double-prefixed GitHub URL.
  - Updated the regression in `Tests/SaneClipTests.swift` so this route cannot drift back.
  - Updated GitHub templates/privacy contact copy so public issues warn about sensitive diagnostics and large media.
  - Cross-repo guard: `SaneProcess/scripts/automation/github_reporting_guard_test.py` verifies this path.

- 2026-05-12 v2.3.4 runtime barrier pass:
  - Fixed Capture Text after the macOS screen/window picker by replacing the post-selection `SCScreenshotManager.captureImage` path with a picker-backed `SCStream` first-frame capture path in `Core/Capture/ScreenCaptureService.swift`.
  - Mini proof after the fix: `./scripts/SaneMaster.rb verify --timeout 1200` passed 152 tests, `./scripts/SaneMaster.rb customer_ui_sweep --no-exit` passed, and the live release build completed Cmd-Shift-Ctrl-T picker selection with OCR clipboard output `SaneClip OCR final proof golf hotel 2026`.
  - Visual proof receipt: `outputs/visual_smoke/visual_smoke_20260512-213744_72234/receipt.json`; clean local copy: `/Users/sj/Desktop/Screenshots/saneclip-mini-proof/final-clean-screen-no-popover.png`.
  - Regenerated `SaneClip.xcodeproj` from `project.yml`; the staged Mini app now reports `CFBundleShortVersionString=2.3.4` and `CFBundleVersion=2304`.
  - Fixed the history shortcut root issue by moving the customer-facing history shortcut to Command-Shift-Control-Y and opening a floating `SaneClip History` window instead of depending on menu-bar popover anchoring.
  - Mini upgrade-path proof: simulated old Command-Shift-V defaults, relaunched `2.3.4/2304`, verified migration to `{"carbonModifiers":4864,"carbonKeyCode":16}`, pressed Command-Shift-Control-Y, observed `SaneClip History`, then pressed it again and observed the window close.
  - Mini `./scripts/SaneMaster.rb verify --timeout 1200` passed 152 tests after the regenerated project and shortcut changes.
  - Mini `./scripts/SaneMaster.rb customer_ui_sweep --no-exit` and `customer_ui_contract --no-exit` passed with 12 release-required actions; receipt generated `2026-05-12T22:19:37Z`.
  - Snippets Pro runtime proof passed: opened Snippets settings, verified sample snippets, clicked `Copy for Manual Paste` for `Current Date` and observed `May 12, 2026` on the clipboard, then clicked `Paste Now` into a real TextEdit document and observed `Snippet target: May 12, 2026`.
  - The earlier Capture Text Mini permission block is superseded: the Mini Screen Recording path was accepted, the picker/OCR workflow completed, and the root app bug was fixed in code.
  - Edit/save has code/unit proof via `Edit sheet saves item changes through the batch update path`, but the customer context-menu click path is not yet runtime-complete in this SSH automation session; AX and coordinate right-click did not open the SwiftUI context menu. Do not close GitHub #9 until a real right-click/context-menu edit/save pass is captured.

- 2026-05-12 customer-facing action release gate is now recorded for SaneClip:
  - Added `Tests/CustomerUIActions.yml`, `scripts/customer_ui_action_sweep.rb`, and `.sane/customer_ui_action_receipt.json`.
  - `./scripts/SaneMaster.rb customer_ui_contract --no-exit` passes with 12 required actions covered; receipt generated `2026-05-12T03:43:51Z` on host `mini`.
  - Refreshed `.claude/research.md` for the existing `saneclip-editor-shortcuts` guard with current Apple SwiftUI docs, KeyboardShortcuts upstream scope, GitHub #9/#10 status, and local source checks.
  - Mini `./scripts/SaneMaster.rb verify` passed 152 tests after the guard-clearing research refresh.

- 2026-05-09 visual/discoverability and tester-feedback pass:
  - Dock right-click and menu-bar right-click are expected to expose the same customer-critical actions through the shared menu contract: Settings, License, Check for Updates, About / Report a Bug, and Quit.
  - Capture Text is now named `Capture Text from Screen` in menus, settings, and permission copy so it does not read like generic clipboard text capture.
  - Screen Recording permission copy now names the real capabilities: Capture Screenshot and Capture Text from Screen.
  - History item editing uses a single batch update path so content, title/tags/collection/note, pinned copies, and paste-stack mirrors do not drift.
  - Snippet rows now expose a visible Paste/Paste Pro action and the context menu includes Paste before edit/manage actions, improving discoverability.
  - Shortcuts settings includes an inline Reset affordance for Show Clipboard History that restores Command-Shift-Control-Y; `2.3.4` migrates the unreliable legacy Command-Shift-V default to this combo.
  - Latest recorded Mini verification for this pass: SaneClip verify passed with 152 tests on 2026-05-09 after the Reset affordance landed. The run includes `Edit sheet saves item changes through the batch update path`, which maps to Noah's trapped edit-window report in GitHub #9.
  - Live GitHub state at closeout: `#9` edit-save, `#10` clipboard-history shortcut, `#11` Capture Text, and `#12` snippets paste discoverability remain open and map to this local pass. Do not close or comment publicly without exact draft approval.

- The current repo version is `2.3.4`; this is the Capture Text stream-path and shortcut-reliability patch train.
- `CHANGELOG.md` is the current release ledger. Use it instead of the stale `v2.0 released / App Store REJECTED` summary below.
- Treat the older sections in this file as archival notes only.

## Addendum - 2026-04-23 (Capture to SaneClip v1)

- Added `Capture Screenshot...` and `Capture Text...` to the main `Edit` menu, the menu bar shell, and the shortcuts settings tab.
- New defaults:
  - `Cmd+Shift+Ctrl+S` → capture screenshot
  - `Cmd+Shift+Ctrl+T` → capture text
- Main implementation lives in:
  - `Core/Capture/ScreenCaptureService.swift`
  - `Core/Capture/CaptureOCRService.swift`
  - `Core/Capture/SaneClipAppDelegate+Capture.swift`
  - `Core/ClipboardManager.swift`
  - `UI/History/ImageCapturePreviewSheet.swift`
- Screenshot capture now stores the original PNG plus the downsized thumbnail in history persistence.
- Text capture now OCRs the selected screen/window and saves the recognized text as a normal clipboard item with source app `Screen Capture`.
- Captured screenshot image items can carry OCR sidecar text for search, preview, copy-OCR, and export workflows.
- Onboarding/settings copy was updated so the app no longer claims screenshots are disabled.

### Important Runtime Fix

- The first implementation could get stuck in `capture already in progress` after the picker selection. Logs showed `SCContentSharingPicker` delivered the selected filter, but the still-image capture never completed.
- Fix: dismiss the picker before still capture, use a guarded selection-resume path, and use `SCScreenshotManager.captureScreenshot(...)` on macOS 26+ with `captureImage(...)` fallback.
- Verified on the Mini:
  - picker appears correctly
  - `Capture Text` copies OCR text to the clipboard and writes a `Screen Capture` history item
  - repeated text captures work without getting stuck
  - `Capture Screenshot` puts image data on the pasteboard and writes both thumbnail + original image assets to persisted history

### Persistence Path Gotcha

- For the live Mini verification run, history and image assets were written under the container path:
  - `~/Library/Containers/com.saneclip.app/Data/Library/Application Support/SaneClip/`
- Do not assume the non-sandboxed `~/Library/Application Support/SaneClip/` path during release verification if the canonical app on the Mini is using the containerized lane.

### App Store Status After Capture Work

- `appstore_preflight` is clean for macOS after adding `NSScreenCaptureUsageDescription` to both `SaneClip/Info.plist` and `SaneClip/Info-AppStore.plist`.
- `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` were bumped to `2.3.0` / `2300`; App Store Connect reports both macOS and iOS `2.3.0` lanes clear.
- Latest App Store preflight result: no blockers, only the expected uncommitted-files warning.
- Latest Mini verification: `SaneMaster verify --timeout 1800` passed `143/143` tests. Remaining lint warnings are existing file-length warnings in `SaneClipApp.swift` and `Core/Sync/SyncCoordinator.swift`.
- Latest Mini runtime check: signed Release build staged to `/Applications/SaneClip.app`, launched successfully, and compiled app plist shows `CFBundleShortVersionString=2.3.0`, `CFBundleVersion=2300`, and the screen-capture usage string.
- Latest visual check: fresh Mini render screenshots in `/tmp/saneclip-capture-renders` copied to `outputs/capture-renders/latest`; direct inspection showed capture controls, shortcuts, image OCR rows, and About screen are professional.

### Closeout - 2026-04-23

#### Done
- Capture/OCR feature set is implemented, formatted to the repo's SwiftLint style, and prepared as `2.3.0` build `2300`.
- Mini verification passed after final formatting: `143/143` tests, signed Release build staged/launched from `/Applications/SaneClip.app`, and App Store preflight has no blockers.
- At the 2026-04-23 capture closeout, `gh issue list --limit 20` returned no open issues. This is now superseded by the 2026-05-09 live issue state above (`#9`-`#12` open).

#### Docs
- `SESSION_HANDOFF.md` and Serena memory `SaneClip/capture-v1-apr23-2026` are current for this work.

#### SOP
- SOP compliance: 9/10. Remaining gap is the intentional human-click ScreenCaptureKit picker E2E pass, which is blocked from reliable synthetic automation by macOS security.

#### Next
- On the Mini tomorrow, trigger Capture Screenshot/Text and manually click the Apple ScreenCaptureKit picker Share button once, then verify the resulting image/OCR item appears in SaneClip history.
- If that human-click E2E passes, update marketing/screenshots/release notes for the `2.3.0` capture workflow.

## Addendum - 2026-04-14 (Pricing Rollout)

- SaneClip pricing is now `Basic free + Pro $14.99 once` for both the direct lane and the App Store lane.
- The business model stays the same: free Basic, one-time Pro unlock, no subscription, and the StoreKit product ID remains `com.saneclip.app.pro.unlock`.
- The canonical source of truth is `/Users/sj/SaneApps/apps/SaneClip`. The `/Users/sj/SaneApps/release/SaneClip` mirror was updated with the same public-facing price copy so it does not drift back to `$6.99`.
- Price-copy updates landed in `.saneprocess`, `README.md`, `docs/index.html`, `docs/guides.html`, and the pricing CTAs across the guide pages in both trees.
- The homepage schema `downloadUrl` now points to `/download` to match the free Basic model instead of a paid checkout URL.

### Post-change Tracking

1. Watch direct conversion from free download to Pro checkout at the new `$14.99` price.
2. Watch App Store conversion after the matching IAP price is updated in App Store Connect.
3. Confirm future docs audits do not reintroduce the old `$5` or `$6.99` assumptions.
4. Re-run a visual spot check on the live homepage, `/download`, `/guides`, and one long-tail guide after deployment.

## Archived Notes

## Addendum - 2026-03-17 (Setapp Planning)

- Setapp single-app distribution is now documented as a planned third macOS channel for SaneClip.
- Direct Lemon Squeezy + Sparkle remains the website/direct business path.
- App Store stays its own StoreKit/App Store-updates lane.
- Setapp-specific blockers/gotchas are now captured in `ARCHITECTURE.md` and `.claude/research.md`:
  - separate `-setapp` bundle ID
  - no Sparkle / no direct licensing UI / no donate UI in the Setapp build
  - universal-binary readiness still needs proof
  - widget/extension bundle-family drift needs explicit review if they ship in the Setapp lane

## Addendum - 2026-03-04 (Planned Next Session)

### New Customer Feature Request
- Email #205 (Court Hubbard): request an option to open clipboard history at current mouse cursor location.
- Planned implementation: **optional setting**, default OFF, no behavior change unless enabled.

### Tomorrow Release Upgrade Checklist (SaneClip)
- Run full Mini E2E for latest SaneClip features before release decision.
- Verify free vs Pro gates end-to-end on Mini.
- Verify iOS/iPad App Store lane metadata correctness (description, subtitle, accessibility declaration display).
- Confirm website copy + screenshots match current feature set before publish.

### Mini E2E Regression List (must run)
1. Open history via shortcut with default setting (anchor at menu bar icon).
2. Enable `Open history at mouse cursor`; verify opens near cursor on primary and secondary display.
3. Verify popover remains fully on-screen at all 4 screen corners (clamped positioning).
4. Verify Touch ID-protected history still prompts correctly and opens in expected position.
5. Verify `reopen history after paste` still reopens correctly with cursor mode ON/OFF.
6. Verify Pro-only shortcuts and settings remain gated in Basic mode.
7. Verify core complaints path: drag/move/visibility behavior on SaneBar remains unaffected (cross-app sanity check).

## Current State: v2.1 (code) — v2.0 Released (DMG) — App Store REJECTED — Needs Resubmission

### What Was Done This Session (Feb 17)

**Fixed GitHub #2: "Paste as UPPERCASE creates duplicate history entry"**

1. **Replaced `isSelfWrite` boolean with `selfWriteChangeCount` tracking** — `ClipboardManager.swift`. Stores `pasteboard.changeCount` after self-writes. `checkClipboard()` skips while `pasteboard.changeCount <= selfWriteChangeCount`. More robust than boolean — immune to dual-increment edge cases.

2. **Updated all 6 paste methods** — `paste()`, `pasteAsPlainText()`, `pasteSmartMode()`, `pasteWithTransform()`, `pasteSnippet()`, `copyWithoutPaste()` — all now set `selfWriteChangeCount = pasteboard.changeCount` after writing.

3. **Added `isPasting` guard** to `dismissAndPaste()` — prevents overlapping Cmd+V simulations from rapid clicks.

4. **Backward-compatible `isSelfWrite` computed property** — URLSchemeHandler.swift still works via the computed accessor.

5. **Ran full critic review** — 21 external review passes flagged the `isSelfWrite` race. Consensus synthesis tagged 3 CERTAIN, 3 HIGH, 5 MEDIUM issues.

**Commit:** `7014863` — pushed to origin/main. Pre-commit AI review (mistral): LGTM.

**Build:** 55/55 tests passed. E2E tested manually — paste-as-uppercase works, no duplicates.

### Bug Discovered: Timer Stall (Pre-existing, NOT fixed)

During e2e testing, discovered clipboard monitoring timer stalls after processing a clipboard event. Likely because `saveHistory()` (JSON encode + encryption + file write + widget update) runs synchronously on the main actor and blocks the RunLoop. This explains why some users may see clipboard capture "miss" copies if they happen during a save. **Needs investigation next session.**

Serena memory: `selfwrite-changecount-fix-feb17`

### Glenn's Issues (Email #48) — Status

| Issue | Status | Notes |
|-------|--------|-------|
| Paste doesn't work (click sound, no paste) | NEEDS VERIFICATION | Glenn has Accessibility permission (logs confirm). CGEvent posts but Cmd+V may not reach target app. 300ms dismiss delay might be insufficient. |
| "[Image]" text instead of thumbnail | FIXED | Glenn confirmed |
| Paste as UPPERCASE creates duplicate | **FIXED** (commit 7014863) | selfWriteChangeCount tracking |
| Notes/descriptions on clips | PLANNED | Plan at `~/.claude/plans/jaunty-cooking-goblet.md`. Not yet implemented. |

### PRIORITY: App Store Approval

**Both macOS and iOS submissions REJECTED.** This is the #1 priority. Steps:

1. **Check ASC for specific rejection reasons** — may need to log into App Store Connect
2. **Known code fixes already in place:** `#if APP_STORE` guards, `showCopiedNotification()`, accessibility alert, onboarding enforcement, FeedbackView
3. **Doc fixes already applied:** privacy policy, website version, support page, README
4. **May need:** PrivacyInfo.xcprivacy, real iPad screenshots, bump version/build numbers
5. **Resubmit** both macOS and iOS builds

### Open GitHub Issues

| # | Title | Status |
|---|-------|--------|
| 1 | Help Wanted: Demo Videos & Social Media | OPEN |
| 2 | Paste as UPPERCASE bug | **CLOSED** (commit 7014863) |

### Notes Feature Plan (Glenn's Request)

Plan exists at `~/.claude/plans/jaunty-cooking-goblet.md` — add `note: String?` to ClipboardItem, SavedClipboardItem, SharedClipboardItem. Update ClipboardManager save/load. UI: note indicator in row, context menu "Add Note...", search includes notes. 6 files to edit. Not yet implemented.

---

## Release Status

### Direct Distribution (DMG/Sparkle)

| Version | Build | Status |
|---------|-------|--------|
| **2.0** | 7 | **RELEASED** |
| 2.1 | 21 | Code ready, not released as DMG |

### App Store

| Platform | Version | Build | State |
|----------|---------|-------|-------|
| **macOS** | 1.0 | 6 | **REJECTED** |
| **iOS** | 1.0 | 2 | **REJECTED** |

---

## Gotchas

| Issue | Detail |
|-------|--------|
| Timer stall | `saveHistory()` blocks main actor, timer stops firing. Pre-existing. |
| ASC REST API 401 | Use fastlane for ASC, not PyJWT |
| Debug storage path | Non-sandboxed → `~/Library/Application Support/SaneClip/` |
| release.sh env vars | Needs `TEAM_ID=M78L6FXD48` and `SIGNING_IDENTITY` |
| iPad screenshots | Scaled from iPhone, not real iPad captures |

---

## Previous Sessions

- Feb 16: iPad onboarding layout fix, website CSS fix, Glenn email response, critic review started
- Feb 14: CX parity fixes (permission detection, DiagnosticsService, FeedbackView, onboarding enforcement)
- Feb 13: Menu bar right-click, dock right-click, Services integration, PDF export
- Feb 9: Infrastructure validation, Mac mini testing
- Feb 7: iOS visual polish, iOS app overhaul
- Feb 3: SaneClip 1.4 DMG release
# SaneClip Session Handoff

## Current State (2026-05-12 Capture Text Permission Loop)

- Root cause confirmed on the Mini: the ScreenCaptureKit picker could return a selection, but `SCScreenshotManager.captureImage(contentFilter:configuration:)` then failed with `declined TCC` for SaneClip. The old code also had an early `CGPreflightScreenCaptureAccess()` gate that could reopen the app's permission prompt before the picker flow.
- Fix implemented in `Core/Capture/ScreenCaptureService.swift`: Capture Text now lets `SCContentSharingPicker` own selection permission, then captures the selected content from the picker filter with `SCStream` + first video sample instead of `SCScreenshotManager.captureImage`. `SCStreamErrorDomain` code `-3801` is normalized back to the app's Screen Recording permission error.
- Tests updated in `Tests/SaneClipTests.swift` and `scripts/customer_ui_action_sweep.rb` to require the `SCStreamOutput`/`CMSampleBufferGetImageBuffer` path and to reject `SCScreenshotManager.captureImage` plus the old early runtime permission guard.
- Mini verification passed after the final source sync: `./scripts/SaneMaster.rb verify --timeout 1200` reported 152/152 tests passing.
- Mini customer-surface proof passed: `./scripts/SaneMaster.rb customer_ui_sweep --no-exit` reported `Workflow sweep and contract passed`.
- Final runtime proof on the Mini used `/Applications/SaneClip.app` staged by `./scripts/SaneMaster.rb test_mode --release --no-logs`. Command-Control-Shift-T opened the picker, a screen choice completed, and the clipboard contained `SaneClip OCR final proof golf hotel 2026`. Recent SaneClip logs show picker selection, `SCStream addStreamOutput`, `startCapture`, and `stopCapture` without the previous `declined TCC` failure.
- Final visual receipt: `outputs/visual_smoke/visual_smoke_20260512-213744_72234/receipt.json` passed with Terminal-host screenshots and no cleanliness issues. Local copied proof: `/Users/sj/Desktop/Screenshots/saneclip-mini-proof/final-clean-screen-no-popover.png`.

## Current State (2026-05-09 Launch Crash / Release Readiness)

- Customer email #688 from Peter included `SaneClip-2026-05-09-143149.ips`; SaneClip 2.3.2 crashed at dyld launch on macOS 15.7.5 with missing ScreenCaptureKit symbol `_OBJC_CLASS_$_SCScreenshotConfiguration`.
- Root cause: `Core/Capture/ScreenCaptureService.swift` referenced the macOS 26-only `SCScreenshotConfiguration` class while the direct build ships with minimum macOS 15.0. The reference made the binary unsafe on current macOS 15 even though the code was inside an availability branch.
- Superseded on 2026-05-12: `SCScreenshotManager.captureImage` also failed after picker selection on some systems. The current fix uses the picker-backed `SCStream` first-frame path and tests assert the old still-image API is absent.
- Must verify before release: Mini `./scripts/SaneMaster.rb verify --timeout 1200`, binary symbol scan for no `SCScreenshotConfiguration`, release-mode launch, then draft a reply to #688 and resolve duplicate #685 after user approval.
- Open GitHub issues #9-#12 are still marked `release:patched-pending` and need maintainer replies after verification.

## Launch Ops Calendar - 2026-05-14

- `.outreach.yml` now classifies SaneClip as `released_but_launch_blocked_until_risk_cleanup`.
- Scheduled gates: launch cleanup on 2026-05-23 and Clipboard/OCR launch decision on 2026-05-27. Do not run a public launch before piracy/DMCA triage, open issue replies, and fresh Mini release proof are clean.
- 2026-05-14 launch package update: fixed landing-page static routes in `docs/index.html` (`Download Free`, `Privacy`, `Help`) and generated local Product Hunt candidate assets at `docs/images/product-hunt-thumbnail-240.png` and `docs/images/product-hunt-gallery-01.png` through `03.png`, plus `Videos/saneclip-private-clipboard-30s.mp4` (1920x1080, 30.0s). Current launch gate remains no-go because DMCA/support/App Store cleanup is still unresolved.

## Launch Ops Calendar - 2026-05-15

- Mini `./scripts/SaneMaster.rb launch_readiness` returned nonzero for SaneClip. No launch, directory, or public reply action was taken.
- Blockers recorded from the gate: the active piracy page still needs DMCA handling, GitHub issues `#9` through `#12` still need verified replies or explicit no-go status, and App Store/iOS metadata plus conversion surfaces need a fresh check before larger traffic.
- Existing support-surface URLs remain unchanged: [awesome-mac](https://github.com/jaywcjlove/awesome-mac/pull/1804) and [awesome-macOS](https://github.com/iCHAIT/awesome-macOS/pull/698).
- Next launch-ops date stays 2026-05-23 for cleanup, not public launch.

## Launch Ops Calendar - 2026-05-16

- Mini `./scripts/SaneMaster.rb launch_readiness --json` stayed red for SaneClip, so no launch, directory, or public reply action was taken.
- Fresh blocker receipt: the piracy page still needs DMCA handling, GitHub issues `#9` through `#12` still need verified replies or explicit no-go status, App Store/iOS metadata plus conversion surfaces still need a fresh check, and the launch video remains local-only until the cleanup lane is complete.
- Existing support-surface URLs remain unchanged: [awesome-mac](https://github.com/jaywcjlove/awesome-mac/pull/1804) and [awesome-macOS](https://github.com/iCHAIT/awesome-macOS/pull/698).
- Next launch-ops date stays 2026-05-23 for cleanup, not public launch.

## Launch Ops Calendar - 2026-05-17

- Mini `./scripts/SaneMaster.rb launch_readiness --json` stayed red again for SaneClip, so no launch, directory, or public reply action was taken.
- Fresh blocker receipt: the piracy page is still `needs_dmca`, GitHub issues `#9` through `#12` still need verified replies or explicit no-go status, App Store/iOS metadata plus conversion surfaces still need a fresh check, and the 30-second video remains local-only until the cleanup lane is complete.
- Existing support-surface URLs remain unchanged: [awesome-mac](https://github.com/jaywcjlove/awesome-mac/pull/1804) and [awesome-macOS](https://github.com/iCHAIT/awesome-macOS/pull/698).
- Next launch-ops date stays 2026-05-23 for cleanup, not public launch.

## Launch Ops Calendar - 2026-05-18

- Mini `./scripts/SaneMaster.rb launch_readiness` stayed red again for SaneClip, so no launch, directory, or public reply action was taken.
- Fresh blocker receipt: the piracy page is still `needs_dmca`, GitHub issues `#9` through `#12` still need verified replies or explicit no-go status, App Store/iOS metadata plus conversion surfaces still need a fresh check, and the 30-second video remains local-only until the cleanup lane is complete.
- Existing support-surface URLs remain unchanged: [awesome-mac](https://github.com/jaywcjlove/awesome-mac/pull/1804) and [awesome-macOS](https://github.com/iCHAIT/awesome-macOS/pull/698).
- Next launch-ops date stays 2026-05-23 for cleanup, not public launch.
