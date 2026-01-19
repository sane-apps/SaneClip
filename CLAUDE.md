# SaneClip - Claude Code Project SOP

> Clipboard manager for macOS with Touch ID security

---

## Project Location

| Path | Description |
|------|-------------|
| **This project** | `~/SaneApps/apps/SaneClip/` |
| **Save outputs** | `~/SaneApps/apps/SaneClip/outputs/` |
| **Screenshots** | `~/Desktop/Screenshots/` (label with project prefix) |
| **Homebrew tap** | `~/SaneApps/infra/homebrew-saneclip/` |
| **Website** | `~/SaneApps/web/saneclip.com/` |
| **Shared UI** | `~/SaneApps/infra/SaneUI/` |
| **Hooks/tooling** | `~/SaneApps/infra/SaneProcess/` |

**Sister apps:** SaneBar, SaneVideo, SaneSync, SaneHosts, SaneAI

---

## ⚠️ BUNDLE IDs - DO NOT CONFUSE

| Config | Bundle ID | Use |
|--------|-----------|-----|
| **Debug** | `com.saneclip.dev` | Local testing ONLY |
| **Release** | `com.saneclip.app` | Production/users |

**NEVER:**
- Run `tccutil reset` against `.app` bundle ID
- Put `.dev` bundle ID in release scripts or shipped code
- Confuse which is which during releases

---

## Where to Look First

| Need | Check |
|------|-------|
| Build/test commands | XcodeBuildMCP (see defaults below) |
| Project structure | `project.yml` (XcodeGen config) |
| Past bugs/learnings | `.claude/memory.json` or MCP memory |
| Touch ID/security | `Services/` directory |
| Clipboard logic | `ClipboardManager.swift` |
| UI components | `Views/` directory |

---

## XcodeBuildMCP Session Defaults

Set these at session start:

```
mcp__XcodeBuildMCP__session-set-defaults:
  projectPath: ~/SaneApps/apps/SaneClip/SaneClip.xcodeproj
  scheme: SaneClip
  arch: arm64
```

Then use: `build_macos`, `test_macos`, `build_run_macos`

## Build Commands

```bash
# Generate Xcode project from project.yml
xcodegen generate

# Build
xcodebuild -project SaneClip.xcodeproj -scheme SaneClip -configuration Debug build

# Run tests
xcodebuild -project SaneClip.xcodeproj -scheme SaneClip test

# Or use XcodeBuildMCP after setting defaults
```

## Project Structure

```
SaneClip/
├── SaneClipApp.swift       # Main app with AppDelegate, ClipboardManager, ClipboardItem
├── main.swift              # App entry point
├── Core/
│   ├── Models/             # Data models (placeholder for expansion)
│   └── Services/           # Services (placeholder for expansion)
├── UI/
│   ├── Settings/           # SettingsView, SettingsModel
│   └── Onboarding/         # OnboardingView
├── Resources/              # Assets, entitlements
├── Tests/                  # Unit tests
├── scripts/                # Build automation scripts
├── docs/                   # GitHub Pages website
└── homebrew/               # Homebrew cask formula
```

## Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| ClipboardManager | SaneClipApp.swift | Monitors pasteboard, manages history |
| ClipboardItem | SaneClipApp.swift | Individual clipboard entry model |
| SettingsManager | SaneClipApp.swift | User preferences persistence |
| AppDelegate | SaneClipApp.swift | Menu bar setup, popover management |
| SettingsView | UI/Settings/ | Settings window UI |
| SettingsModel | UI/Settings/ | Observable settings state |

## Menu Bar App

- **LSUIElement: true** - No dock icon, menu bar only
- Uses NSPopover for clipboard history panel
- Keyboard shortcuts via KeyboardShortcuts package

## UI Testing

This is a **menu bar app**. Use `macos-automator` MCP for UI testing:

```
mcp__macos-automator__get_scripting_tips search_term: "menu bar"
mcp__macos-automator__execute_script kb_script_id: "..."
```

XcodeBuildMCP simulator tools are for iOS only.

## Dependencies

| Package | Purpose |
|---------|---------|
| KeyboardShortcuts | Global hotkey support |
| Sparkle | Auto-update framework |

## Coding Standards

See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Swift 5.9+ features, @Observable pattern
- SwiftUI for all UI
- View bodies under 50 lines
- Conventional commit messages

## Release Process

```bash
# 1. Build release
xcodebuild -project SaneClip.xcodeproj -scheme SaneClip -configuration Release archive

# 2. Notarize (uses keychain profile)
xcrun notarytool submit SaneClip.dmg --keychain-profile "notarytool" --wait

# 3. Staple
xcrun stapler staple SaneClip.dmg
```

## Memory MCP Usage

```
# Project-scoped searches
mcp__plugin_claude-mem_mcp-search__search query: "clipboard" project: "SaneClip"
```
