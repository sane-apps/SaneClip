# Session Handoff - 2026-01-23

> **Navigation**
> | Bugs | Features | How to Work | Releases | Testimonials |
> |------|----------|-------------|----------|--------------|
> | [BUG_TRACKING.md](BUG_TRACKING.md) | [marketing/feature-requests.md](marketing/feature-requests.md) | [DEVELOPMENT.md](DEVELOPMENT.md) | [CHANGELOG.md](CHANGELOG.md) | [marketing/testimonials.md](marketing/testimonials.md) |

---

## 🧪 PRIORITY: Test Cloudflare Sparkle Updates

**Why here:** SaneClip has no active users = safe to test. SaneBar has paying customers.

**Goal:** Verify Sparkle auto-updates work from Cloudflare R2 before switching SaneBar production.

**Test plan:**
1. Upload old SaneClip DMG to R2 bucket (`sanebar-downloads` or new bucket)
2. Create SaneClip appcast pointing to Cloudflare
3. Install old version locally
4. Trigger "Check for Updates"
5. Verify download + signature verification + install works
6. If success → switch SaneBar appcast to Cloudflare, delete GitHub releases

**Infrastructure (already built for SaneBar):**
- R2 bucket: `sanebar-downloads`
- Worker: `dist.sanebar.com`
- Can reuse or create `dist.saneclip.com`

---

## Previous Session (2026-01-19)

### Completed

### Security Audit & Fixes
- Added transient/concealed clipboard type detection (password protection)
- Added hardcoded password manager bundle IDs exclusion list
- Added `.completeFileProtection` for `history.json` persistence

### Refactoring
- Extracted `ClipboardManager`, `SettingsModel` to `Core/`
- Extracted `ClipboardItem`, `SavedClipboardItem` to `Core/Models/`
- Extracted `ClipboardHistoryView`, `ClipboardItemRow` to `UI/History/`

### UI/UX Improvements
- Single click to paste (removed redundant document icon button)
- Code detection with monospaced font
- Stats now show 'wd' and 'ch' for clarity
- Added 'Paste as Plain Text' to context menu
- **Hover highlighting** - Cards brighten, scale, and show pointer cursor on hover
- **Content-type icons** - Link, code, or text icon for faster scanning
- **Glass material background** - Modern macOS material blur effect

### Smart Features
- **URL tracking stripping** - Auto-removes utm_*, fbclid, gclid, etc. from URLs
- **Pinned items persistence** - Pinned items survive app restart

### Release Prep
- Updated `MARKETING_VERSION` to 1.1 with build 3
- Fixed appcast.xml (build numbers, stats description)
- Updated documentation (TODO.md, ROADMAP.md)

## Current State

**Version 1.1 ready for release.** All features verified ✅

## Pending Tasks

### ⚠️ UPDATE MARKETING IMAGES
- Screenshots in `docs/images/` are outdated (old UI with paste buttons)
- Need new screenshots showing:
  - Clean row design (no document icon)
  - "wd · ch" stats format
  - Hover highlighting effect

### Other
- Consider adding unit tests for `ClipboardManager`

## Key Documentation
- `APP_STORE_CHECKLIST.md`: Guide for dual distribution (App Store + Website).
- `TODO.md`: Current tasks and recent completions.
- `ROADMAP.md`: Future feature planning.

## Bundle IDs (DO NOT CONFUSE)

| Config | Bundle ID | Use |
|--------|-----------|-----|
| Debug | `com.saneclip.dev` | Local testing ONLY |
| Release | `com.saneclip.app` | Production/users |

## Quick Commands

```bash
# Clean launch (ALWAYS use this pattern)
killall SaneClip 2>/dev/null; sleep 1; pgrep SaneClip && echo "ABORT" || open /path/to/SaneClip.app

# Reset onboarding (debug only)
defaults delete com.saneclip.dev hasCompletedOnboarding

# Build
xcodebuild -project SaneClip.xcodeproj -scheme SaneClip -configuration Debug build
```
