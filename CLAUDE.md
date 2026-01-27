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
# Set XcodeBuildMCP defaults (once per session)
mcp__XcodeBuildMCP__session-set-defaults:
  projectPath: ~/SaneApps/apps/SaneClip/SaneClip.xcodeproj
  scheme: SaneClip
  arch: arm64

# Then use:
build_macos        # Build
test_macos         # Run tests
build_run_macos    # Build and launch
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
| Past learnings | `mcp__plugin_claude-mem_mcp-search__search` |

---

## Memory MCP

```
mcp__plugin_claude-mem_mcp-search__search query: "topic" project: "SaneClip"
```

---

## Full Documentation

- **[DEVELOPMENT.md](DEVELOPMENT.md)** - Complete SOP with 12 rules, research protocol, circuit breaker
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Code standards, commit format
- **[SESSION_HANDOFF.md](SESSION_HANDOFF.md)** - Current session context and pending tasks
