# Session Handoff - 2026-02-09 (11:01 PM)

## Current State: v2.0 Released (DMG + LemonSqueezy) — Both Platforms WAITING_FOR_REVIEW (App Store)

### What Was Done This Session (Latest)

1. **Live tested all new features** — Clipboard capture confirmed working, history popover verified (69 items), source-aware colors visible, URL scheme responsive, keyboard shortcuts registered
2. **Maps vs Messages color fix verified** — Already fixed: Maps `0x4B9FE8` (blue) vs Messages `0x5EC2A0` (sage green)
3. **macOS v2.0 version bump** — MARKETING_VERSION 1.4→2.0, CURRENT_PROJECT_VERSION 6→7 (macOS + macOS Widgets only, iOS stays 1.0)
4. **v2.0 DMG built, signed, notarized** — Using `release.sh` with correct Developer ID identity
5. **v2.0 deployed to production** — DMG uploaded to R2, appcast.xml updated, website deployed via Cloudflare Pages
6. **v2.0 DMG copied to Desktop** — `~/Desktop/SaneClip-2.0.dmg` for LemonSqueezy upload
7. **Debug storage location clarified** — Non-sandboxed debug builds write to `~/Library/Application Support/SaneClip/` (NOT container path)

### What Was Done Earlier This Session

7. **Website overhaul** — Feature grid reordered, comparison table expanded to 17 rows, consistent blue gradient styling
8. **README comparison table** — Expanded to full 17-row markdown table
9. **12 new SEO guide pages** — Total 17 guides, "Hard Way vs Sane Way" template
10. **iOS Universal Purchase bundle ID migration** — `com.saneclip.app.ios` → `com.saneclip.app`
11. **iOS App Store submission (COMPLETE)** — Archived, uploaded, metadata, screenshots, submitted via fastlane
12. **Fastlane setup** — Appfile, Deliverfile, metadata, screenshots

### Commits This Session

| Hash | Description |
|------|-------------|
| `7b88b1c` | feat: reorder feature grid, unique features first with glow |
| `9929563` | feat: expand comparison table to 17 rows |
| `b1d6a0b` | docs: full comparison table in README |
| `a69d63c` | fix: consistent featured styling on all feature cards |
| `6c8299f` | feat: 12 new SEO guide pages, 17 total |
| `a142a5d` | feat: unify iOS bundle IDs with macOS for Universal Purchase |
| `5f1a0d8` | chore: add encryption compliance, bump iOS build to 2 |
| `f18dafd` | chore: bump macOS version to 2.0 (build 7) |
| `2dcadde` | chore: update appcast for v2.0 |

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
