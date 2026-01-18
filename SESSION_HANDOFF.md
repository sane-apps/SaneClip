# Session Handoff - 2026-01-18

## Completed This Session

### OG Image (Done)
- Redesigned to 1200x630, clean centered design
- Large app icon on left, bold "SaneClip" text, tagline
- Optimized to 80KB for fast loading
- Pushed to main: `docs/images/og-image.png`

### Release Script Update (Done)
- Added `create-dmg` support to `scripts/release.sh`
- Falls back to hdiutil if create-dmg not available
- Created `scripts/dmg-resources/dmg-background.png` (not working yet)

---

## Pending Tasks

### 1. DMG Installer Background (Blocked)

**Problem:** Background PNG covers the Applications folder icon. The icon is there and clickable, but invisible.

**What works:**
- Without background: both icons visible, correct positions
- Icon positions confirmed via AppleScript: SaneClip.app (140,200), Applications (400,200)

**What doesn't work:**
- Any background image causes Applications folder icon to be invisible
- Tried: solid colors, gradients, different sizes, different positions

**Possible cause:** macOS Tahoe Finder bug with background image z-order

**Next steps to try:**
- Research macOS Tahoe + create-dmg issues
- Try different image formats (TIFF, JPG instead of PNG)
- Try setting background via different method (not .background folder)
- Consider shipping without custom background for now

### 2. Onboarding Flow (Not Started)

**Reference:** SaneBar's `UI/OnboardingTipView.swift`

**SaneClip differences:**
- No accessibility permissions needed (uses NSPasteboard, not AX API)
- Onboarding should focus on keyboard shortcuts

**Key shortcuts to teach:**
- `Cmd+Shift+V` - Open clipboard history
- `Cmd+Ctrl+1-9` - Quick paste items 1-9
- `Cmd+Shift+Option+V` - Paste as plain text

**Suggested flow:**
1. Welcome screen with app overview
2. Keyboard shortcuts tutorial
3. Optional: Touch ID setup prompt

---

## Files Modified

- `docs/images/og-image.png` - New OG image
- `scripts/release.sh` - Added create-dmg support
- `scripts/dmg-resources/dmg-background.png` - Created (not working)

---

## Quick Commands

```bash
# Test DMG without background (works)
create-dmg --volname "SaneClip" --window-size 480 300 --icon-size 128 \
  --icon "SaneClip.app" 120 150 --app-drop-link 360 150 \
  build/test.dmg build/Export/SaneClip.app

# Build full release
./scripts/release.sh
```
