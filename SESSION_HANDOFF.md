# Session Handoff — SaneClip

**Last updated:** 2026-04-23
**Current project version:** `2.3.0` (build `2300`)

## Current State

- The current repo version is `2.3.0`; this is the capture/OCR feature train.
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
- Latest visual check: fresh Mini render screenshots in `/tmp/saneclip-capture-renders` copied to `outputs/capture-renders/latest`; direct inspection showed capture controls, shortcuts, image OCR rows, and About screen are professional. NVIDIA vision audit remains blocked by provider HTTP 400, even on small JPEG input.

### Closeout - 2026-04-23

#### Done
- Capture/OCR feature set is implemented, formatted to the repo's SwiftLint style, and prepared as `2.3.0` build `2300`.
- Mini verification passed after final formatting: `143/143` tests, signed Release build staged/launched from `/Applications/SaneClip.app`, and App Store preflight has no blockers.
- `gh issue list --limit 20` returned no open issues at closeout.

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

5. **Ran full critic review** — 21 free NVIDIA reviews (7 perspectives × 3 models: mistral, deepseek, kimi-fast). All 21/21 flagged the isSelfWrite race. Consensus synthesis tagged 3 CERTAIN, 3 HIGH, 5 MEDIUM issues.

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
