# SaneClip - Claude Code Quick Reference

> Clipboard manager for macOS with Touch ID security
>
> **Full SOP:** See [DEVELOPMENT.md](DEVELOPMENT.md) for rules, protocols, and detailed procedures.

---

## Sane Philosophy

```
"Not fear, but power, love, sound mind" — 2 Timothy 1:7

BEFORE YOU SHIP: Does this REDUCE fear or create it?
Full philosophy: ~/SaneApps/meta/Brand/NORTH_STAR.md
```

---

## Bundle IDs - DO NOT CONFUSE

| Config | Bundle ID | Use |
|--------|-----------|-----|
| **Debug** | `com.saneclip.dev` | Local testing ONLY |
| **Release** | `com.saneclip.app` | Production/users |

**NEVER:** Run `tccutil reset` against `.app` bundle ID

---

## Project Locations

| Path | Description |
|------|-------------|
| **This project** | `~/SaneApps/apps/SaneClip/` |
| **Website** | `docs/` (Cloudflare Pages at saneclip.com) |
| **Sister apps** | SaneBar, SaneHosts, SaneVideo, SaneSync |

---

## Quick Start

```
# Xcode Tools (official MCP)
mcp__xcode__XcodeListWindows
mcp__xcode__BuildProject     # Build
mcp__xcode__RunAllTests      # Run tests
mcp__xcode__RenderPreview    # SwiftUI previews
```

---

## Key Files

| Need | Check |
|------|-------|
| Clipboard logic | `Core/ClipboardManager.swift` |
| Settings model | `Core/SettingsModel.swift` |
| Data models | `Core/Models/` |
| UI components | `UI/` directory |
| Project config | `project.yml` (XcodeGen) |
| Past learnings | Serena memories (`read_memory`) or official Memory MCP |

---

## Serena Memories

```
read_memory  # Check past learnings
write_memory # Save important findings
```

---

## Distribution — NO HOMEBREW

SaneApps are distributed via **Cloudflare R2** (`dist.{app}.com`) + Sparkle auto-update. **Do NOT create Homebrew casks/formulas.** No `homebrew/` directory, no `.rb` formula files.

---

## DMG & Icon Rules (CRITICAL)

**App Icons:** Must be FULL SQUARE canvases — no squircle, no drop shadow baked in. macOS applies its own squircle mask. Use `CGImageAlphaInfo.noneSkipLast` for opaque output. See `scripts/generate_icon.swift`.

**DMG Background:** Do NOT use `create-dmg --background` with dark images — Finder renders icon labels in black, unreadable. Omit `--background` entirely; Finder's default adapts to user's light/dark mode with correct text contrast.

**Full details:** Serena memory `dmg-icon-and-background-lessons`

---

## Full Documentation

- **[DEVELOPMENT.md](DEVELOPMENT.md)** - Complete SOP with 12 rules, research protocol, circuit breaker
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Code standards, commit format
- **[SESSION_HANDOFF.md](SESSION_HANDOFF.md)** - Current session context and pending tasks
