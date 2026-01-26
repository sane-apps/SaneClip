# Session Handoff - 2026-01-25 6:50 PM

> **Navigation**
> | Bugs | Features | How to Work | Releases | Testimonials |
> |------|----------|-------------|----------|--------------|
> | [BUG_TRACKING.md](BUG_TRACKING.md) | [marketing/feature-requests.md](marketing/feature-requests.md) | [DEVELOPMENT.md](DEVELOPMENT.md) | [CHANGELOG.md](CHANGELOG.md) | [marketing/testimonials.md](marketing/testimonials.md) |

---

## Completed This Session

### 1. Removed CloudKit/iCloud Sync Completely
**Rationale:** Apple's Developer ID + CloudKit provisioning is broken/painful. Days wasted on portal configuration issues. Feature undermines privacy-first local approach anyway.

**Files Removed:**
- `Core/Sync/CloudKitSyncService.swift`
- `Core/Sync/` folder
- `Core/Encryption/EncryptionService.swift`
- `Core/Encryption/` folder
- `UI/Settings/SyncSettingsView.swift`

**Files Modified:**
- `SaneClip/SaneClip.entitlements` - Removed all iCloud entitlements
- `Widgets/SaneClipWidgets.entitlements` - Removed iCloud entitlements
- `SaneClipApp.swift` - Removed sync observers and handleSyncedItems method
- `Core/URLScheme/URLSchemeHandler.swift` - Removed sync URL scheme handler
- `Core/ClipboardManager.swift` - Removed addSyncedItem method
- `UI/Settings/SettingsView.swift` - Removed Sync tab
- `ROADMAP.md` - Removed iCloud Sync from Phase 3, changed to "100% Local" in comparison

### 2. Fixed Orphaned Subagent Memory Issue
- Identified `--resume` subagent processes eating 2GB+ RAM
- Updated `~/.claude/CLAUDE.md` with smarter cleanup script that only kills true orphans
- Filed GitHub issue: https://github.com/anthropics/claude-code/issues/20874

---

## Build Status

**Release build: PASSING**

```bash
xcodebuild -scheme SaneClip -configuration Release -arch arm64 build
```

---

## Version Info
- Current version in project.yml: 1.2 (build 4)
- Ready for notarization and distribution

---

## Quick Commands

```bash
# Build Release
xcodebuild -scheme SaneClip -configuration Release -arch arm64 build

# Upload DMG to R2
CF_TOKEN=$(security find-generic-password -s cloudflare -a api_token -w)
CF_ACCOUNT="2c267ab06352ba2522114c3081a8c5fa"
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT/r2/buckets/sanebar-downloads/objects/{filename}.dmg" \
  -H "Authorization: Bearer $CF_TOKEN" \
  --data-binary @/path/to/file.dmg

# Notarize
xcrun notarytool submit /path/to/app.dmg --keychain-profile "notarytool" --wait
xcrun stapler staple /path/to/app.dmg
```

---

## What's NOT Changing
- Touch ID protection still works
- All clipboard features intact
- Widgets work (just no iCloud sync)
- Everything stays 100% local

---

## Next Steps
1. Create DMG for v1.2
2. Notarize
3. Upload to Cloudflare R2
4. Update appcast
5. Test Sparkle update flow
