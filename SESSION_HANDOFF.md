# Session Handoff - 2026-01-19

## Completed This Session

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
