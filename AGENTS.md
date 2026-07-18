# SaneClip Agent Instructions

Follow `~/AGENTS.md` first (cross-LLM policy source of truth). This file carries SaneClip-specific facts.

Philosophy: `~/SaneApps/meta/Brand/NORTH_STAR.md`

## What Is This

Clipboard manager for macOS with Touch ID security. Website: saneclip.com (`docs/`, Cloudflare Pages).

## Source Of Truth

- Full SOP, rules, protocols: `DEVELOPMENT.md`
- Code standards, commit format: `CONTRIBUTING.md`
- Architecture: `ARCHITECTURE.md`
- Current session context: `SESSION_HANDOFF.md`
- Project config: `project.yml` (XcodeGen)

Product roster (canonical): macOS = SaneHosts, SaneClip, SaneClick, SaneSales, SaneVideo; iOS = SaneScan (iPhone/iPad only), SaneLot; SaaS = SaneCite. SaneBar is retired (free + OSS, never advertised as a peer product).

## Bundle IDs — DO NOT CONFUSE

| Config | Bundle ID | Use |
|--------|-----------|-----|
| **Debug** | `com.saneclip.dev` | Local testing ONLY |
| **Release** | `com.saneclip.app` | Production/users |

**NEVER** run `tccutil reset` against the `.app` bundle ID.

## Key Files

| Need | Check |
|------|-------|
| Clipboard logic | `Core/ClipboardManager.swift` |
| Settings model | `Core/SettingsModel.swift` |
| Data models | `Core/Models/` |
| UI components | `UI/` directory |

## Build, Test, Release (Mini-first)

- Canonical route: run `ruby scripts/SaneMaster.rb verify` on the Mac Mini (build + tests).
- Local Xcode builds on the Air are an explicitly-approved fallback only.
- Release: run `./scripts/SaneMaster.rb release_preflight`, then `./scripts/SaneMaster.rb appstore_preflight` for App Store lanes, then `bash ~/SaneApps/infra/SaneProcess/scripts/release.sh --project <path> --full --version X.Y.Z --notes "..." --deploy`. The release script publishes the signed ZIP, appcast, website, and Homebrew update through the guarded pipeline.
- Homebrew/distribution policy lives in the SaneProcess docs (`~/SaneApps/infra/SaneProcess/DEVELOPMENT.md`); the tap at `~/SaneApps/homebrew-tap` is a live release channel updated by release.sh.

## App Icon Rule (CRITICAL)

App icons must be FULL SQUARE canvases — no squircle, no baked-in drop shadow; macOS applies its own squircle mask. Use `CGImageAlphaInfo.noneSkipLast` for opaque output. See `scripts/generate_icon.swift`.

## Research & Memory

- Past bugs/learnings: agentmemory `memory_recall` / `memory_smart_search` + Claude file memory. Serena is code-navigation only; its old memories are absorbed into agentmemory.
- Apple frameworks: `apple-docs` MCP. Library docs: `plugin:context7:context7`. GitHub search: `gh` CLI.
