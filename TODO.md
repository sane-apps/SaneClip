# SaneClip TODO

## ✅ Done
- [x] DMG styling - custom background with arrow, proper icon layout
- [x] Website/landing page at saneclip.com
- [x] OG images for social media previews (Twitter, iMessage)
- [x] Sparkle update feed setup
- [x] App source attribution — Show which app each clip came from with icon
- [x] Exclude apps list — Blacklist sensitive apps (1Password, banking, etc.)
- [x] Duplicate detection — Auto-consolidate identical clips
- [x] Keyboard navigation — Arrow keys, vim-style j/k in history list
- [x] Paste count badge — Show how many times each item was pasted
- [x] Security-by-default — Auth required to reduce any security setting

## ✅ Done (v1.1)
- [x] Improved onboarding — First-launch tutorial
- [x] Menu bar icon options — Multiple icon styles
- [x] Sound effects toggle
- [x] Hover highlighting with glass effect
- [x] Content-type icons (link/code/text)
- [x] URL tracking parameter stripping (utm_*, fbclid, etc.)
- [x] Pinned items persistence

## Improvements to Carry Back to SaneBar

### 1. Security-by-Default
Reducing any security setting requires system authentication (Touch ID or password). No master toggle needed - it's automatic.
- Turning OFF protections → requires auth
- Turning ON protections → no auth needed
- Removing items from exclusion lists → requires auth

**Files:** `SettingsView.swift` - `authenticateForSecurityChange()` function

### 2. Dock Visibility on Launch
SaneClip correctly applies dock visibility setting on app launch. SaneBar requires toggling the setting on/off to take effect.

**Fix:** Call `applyDockVisibility()` in `SettingsModel.init()`:
```swift
init() {
    // ... load settings ...
    applyDockVisibility() // Apply immediately on init
}
```

### 3. Settings UI Aesthetics
- Glass effect background with gradient
- Compact row-based sections
- Visual effect blur for dark mode
- Consistent padding and alignment

**Files:** `SettingsView.swift` - `SettingsGradientBackground`, `CompactSection`, `CompactRow`, `CompactToggle`

### 4. Excluded Apps Row-Based UI
Clean row layout instead of chips/tags:
- Each app on its own row
- X button right-aligned
- "Add App..." button (not dropdown menu)
- Opens directly to /Applications folder

## See Also
- [ROADMAP.md](ROADMAP.md) for full feature roadmap
