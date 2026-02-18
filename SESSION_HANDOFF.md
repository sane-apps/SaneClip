# Session Handoff - 2026-02-17

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
