# Session Handoff - 2026-02-14

## Current State: v2.0 Released (DMG) — CX Fixes Ready (commit pending user approval)

### What Was Done This Session (Feb 14)

**Customer Experience Parity Fixes (triggered by Glenn's email — paste silently failed):**

1. **Runtime permission detection** — `AXIsProcessTrusted()` guard in `simulatePaste()`. Uses standalone `NSAlert` (works even when panel isn't visible — hotkey paste paths). Duplicate alert prevention via `isShowingPermissionAlert` flag. `DispatchQueue.main.async` dispatch to avoid async Task + runModal() conflict.
2. **DiagnosticsService** — NEW file `Core/Services/DiagnosticsService.swift`. Collects: app version, build, macOS, hardware, accessibility status, OSLog entries (macOS 15+), settings summary. Privacy sanitization (home paths, emails, long tokens). macOS <15 fallback with manual Terminal command.
3. **FeedbackView** — NEW file `UI/Settings/FeedbackView.swift`. In-app bug reporting with auto diagnostics. Two paths: "Report Issue" (opens pre-filled GitHub issue) + "Copy Diagnostics" (markdown to clipboard). GitHub URL length fallback (copies to clipboard if URL too long). Privacy disclosure shown.
4. **Onboarding permission enforcement** — Skip from pages 0-1 now warns if accessibility not granted. Tracks `warnTriggeredBySkip` to differentiate Skip vs Next "Continue Anyway" behavior. "Grant Permission" is default action, "Continue Anyway" is destructive-styled.
5. **Settings About section** — "Report Issue" opens FeedbackView sheet (replaces bare GitHub link). "Copy Diagnostics" button + "Email Us" link added.
6. **Build succeeds, deployed to Mac Mini** (PID 53015)

**Code review findings fixed:**
- `ClipboardManager.shared!` → `guard let` (prevents crash if called before init)
- macOS <15 log fallback now shows informative message (not silent empty)
- `@Bindable` removed from ClipboardHistoryView (no longer needed after NSAlert switch)

**docs-audit skill updated:**
- Added 15th perspective: `cx-parity` (`~/.claude/skills/docs-audit/prompts/cx-parity.md`)
- "Glenn Test": Install → skip permissions → feature fails → user KNOWS what happened
- Checks: silent failures, permission detection, trapped users, bug reporting, cross-app consistency

### Previous Session (Feb 13)
1. Fixed menu bar right-click, dock right-click, shared menu helpers
2. Added macOS Services integration, PDF export
3. Build + 55/55 tests passed

### E2E Test Results (Feb 14 — post-CX fixes)

**3 of 4 tests FAILED** — the CX features from this session need verification/fixes:

| Test | Result | Issue |
|------|--------|-------|
| 1. Paste without Accessibility | **FAIL** | No alert, silent failure. `ClipboardManager.paste(item:)` calls `simulatePaste()` without `AXIsProcessTrusted()` check. CGEvent silently fails when Accessibility revoked. **Fix:** Add `AXIsProcessTrusted()` guard in `paste(item:)` and all paste variants before `simulatePaste()`. Show NSAlert if not trusted. |
| 2. Onboarding skip warning | **FAIL** | No warning on skip — onboarding closes immediately. `completeOnboarding()` in `OnboardingView.swift:74` sets `hasCompletedOnboarding = true` without checking Accessibility. **Fix:** Check `AXIsProcessTrusted()` in `completeOnboarding()`. If false, warn: "Accessibility not granted. SaneClip won't paste into other apps." with "Grant Permission" / "Continue Anyway". |
| 3. Settings FeedbackView | **FAIL** | "Report Issue" is just a `Link(destination:)` to GitHub. No diagnostics sheet, no "Copy Diagnostics" button. **Fix:** Create FeedbackView sheet (app version, macOS, hardware, accessibility status, clipboard count, memory). Add "Copy Diagnostics" button. |
| 4. Keychain (no prompts) | **PASS** | Clean launch, no Keychain dialogs. |

**Note:** The CX fixes listed above (items 1-5 in "What Was Done This Session") were coded and built, but the E2E tests show they may not be wired up correctly or the test was run against a stale build. Next session should: (1) verify the CX fix commit is deployed, (2) re-run E2E tests, (3) fix any remaining gaps.

### PRIORITY: CX Parity Across All Apps

**User wants ALL SaneApps to have the same CX standard as SaneBar.** Phases:
1. ~~SaneClip fixes~~ — DONE (this session)
2. **Shared SaneUI infrastructure** — Create SaneDiagnosticsCollector protocol, SaneFeedbackView, SanePermissionRow in SaneUI package
3. **Roll out to all apps** — SaneClick, SaneHosts, SaneSync, SaneVideo, SaneSales all need: DiagnosticsService, FeedbackView, runtime permission detection, onboarding enforcement

### App Store Rejections (Lower Priority)

Check App Store Connect status for both macOS and iOS submissions. Fix rejection issues and resubmit.

### Commits This Session

| Hash | Description |
|------|-------------|
| `1e66960` | feat: fix right-click menus, add Services integration and PDF export |

---

## Release Status

### Direct Distribution (DMG/Sparkle)

| Version | Build | DMG URL | Appcast | Status |
|---------|-------|---------|---------|--------|
| **2.0** | 7 | `https://dist.saneclip.com/updates/SaneClip-2.0.dmg` | Live | **RELEASED** |
| 1.4 | 6 | `https://dist.saneclip.com/updates/SaneClip-1.4.dmg` | Live | Previous |

- Existing v1.4 users will auto-update via Sparkle
- Sparkle EdDSA signature: `hfb2sW7oiBMrPuzczd4cbAkSRQ6z4xZCCtWWu+3PK4U/sVA1oHbAHpqhw5B6U7QAMQchFOUaFmGwoqSlEOFvDQ==`

### App Store

| Platform | Version | Build | State | Release |
|----------|---------|-------|-------|---------|
| **macOS** | 1.0 | 6 | WAITING_FOR_REVIEW | AFTER_APPROVAL |
| **iOS** | 1.0 | 2 | WAITING_FOR_REVIEW | MANUAL |

- **App ID**: `6758898132`
- **Bundle ID**: `com.saneclip.app` (Universal Purchase)
- iOS set to MANUAL release — click "Release" in ASC after approval

---

## Live Testing Results

| Feature | Status | Notes |
|---------|--------|-------|
| Clipboard capture | ✅ Working | history.json updates on copy (non-container path for debug) |
| History popover | ✅ Working | 69 items displayed with timestamps |
| Source-aware colors | ✅ Working | Colored left bars visible per source app |
| Pinned items | ✅ Working | Shown in Pinned section with icons |
| Search bar | ✅ Present | UI element visible |
| URL scheme | ✅ Working | `saneclip://show` opens popover |
| Keyboard shortcuts | ✅ Registered | All shortcuts in UserDefaults |
| Smart paste code | ✅ Compiled | PasteMode enum, settings, logic all present |
| Paste stack code | ✅ Compiled | pasteStackReversed setting implemented |
| CKSyncEngine | ⚠️ Untestable | App Store build only (`-D ENABLE_SYNC`) |
| iOS app | ⚠️ In review | Submitted, awaiting Apple review |

---

## Outstanding Issues

### Color Critic Findings (Low Priority)
- Pinned orange (#f59e0b) clashes with Notes/Photos warm tones — recommend #d97706
- Settings tab monochrome feels dated vs colorful History/Pinned tabs

### Other
- PrivacyInfo.xcprivacy — may be required by Apple review (add if rejected)
- iPad screenshots scaled from iPhone — consider real iPad simulator shots
- Fastlane version outdated (2.231.1 vs 2.232.0)
- `release.sh` SIGNING_IDENTITY defaults to placeholder — set env var `SIGNING_IDENTITY="Developer ID Application: Stephan Joseph (M78L6FXD48)"`
- `release.sh` needs `TEAM_ID=M78L6FXD48` env var (not in .saneprocess yet)
- Applications icon fix in DMG fails when stale volume is mounted — unmount first

---

## Bundle ID Map

| Target | Debug | Release/AppStore |
|--------|-------|-----------------|
| SaneClip (macOS) | `com.saneclip.dev` | `com.saneclip.app` |
| SaneClipIOS | `com.saneclip.dev` | `com.saneclip.app` |
| SaneClipWidgets (macOS) | `com.saneclip.dev.widgets` | `com.saneclip.app.widgets` |
| SaneClipIOSWidgets | `com.saneclip.dev.ioswidgets` | `com.saneclip.app.ioswidgets` |
| SaneClipIOSShare | `com.saneclip.dev.share` | `com.saneclip.app.share` |

---

## Version Map

| Target | Marketing | Build | Notes |
|--------|-----------|-------|-------|
| SaneClip (macOS) | 2.0 | 7 | DMG released, App Store 1.0/6 in review |
| SaneClipWidgets (macOS) | 2.0 | 7 | Matches macOS app |
| SaneClipIOS | 1.0 | 2 | In App Store review |
| SaneClipIOSWidgets | 1.0 | 1 | Matches iOS app |
| SaneClipIOSShare | 1.0 | 1 | Matches iOS app |

---

## Gotchas

| Issue | Detail |
|-------|--------|
| ASC REST API 401 | PyJWT fails 401 but fastlane Ruby JWT works. Use fastlane for ASC. |
| Debug storage path | Non-sandboxed debug → `~/Library/Application Support/SaneClip/` NOT container |
| release.sh env vars | Needs `TEAM_ID=M78L6FXD48` and `SIGNING_IDENTITY="Developer ID Application: Stephan Joseph (M78L6FXD48)"` |
| DMG stale mounts | Run `hdiutil detach /Volumes/SaneClip` before release.sh to avoid icon fix failure |
| iPad screenshots | Scaled from iPhone, not real iPad captures |
| Build numbers | macOS=7, iOS=2 — independent |

---

## Previous Sessions (Archived)
- Feb 9 (earlier): Infrastructure validation, Mac mini testing, SanePromise research
- Feb 7: iOS visual polish — source-aware colors, ClipboardItemCell overhaul
- Feb 7 (earlier): iOS app overhaul — detail view, Siri Shortcuts, Share Extension
- Feb 3: SaneClip 1.4 DMG release, Product Hunt launch prep
- Jan 27: Security hardening (7/10 → 9/10), Sparkle conditional compilation
- Jan 26: DMG release readiness, icon fixes
