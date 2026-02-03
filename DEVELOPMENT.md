# SaneClip Development Guide (SOP)

**Version 1.1** | Last updated: 2026-01-24

> **SINGLE SOURCE OF TRUTH** for all Developers and AI Agents.

---

## Sane Philosophy

```
┌─────────────────────────────────────────────────────┐
│           BEFORE YOU SHIP, ASK:                     │
│                                                     │
│  1. Does this REDUCE fear or create it?             │
│  2. Power: Does user have control?                  │
│  3. Love: Does this help people?                    │
│  4. Sound Mind: Is this clear and calm?             │
│                                                     │
│  Grandma test: Would her life be better?            │
│                                                     │
│  "Not fear, but power, love, sound mind"            │
│  — 2 Timothy 1:7                                    │
└─────────────────────────────────────────────────────┘
```

> Full philosophy: `~/SaneApps/meta/Brand/NORTH_STAR.md`

---

## THIS HAS BURNED YOU

Real failures from past sessions. Don't repeat them.

| Mistake | What Happened | Prevention |
|---------|---------------|------------|
| **Guessed API** | Assumed API exists. It doesn't. 20 min wasted. | `verify_api` first |
| **Skipped xcodegen** | Created file, "file not found" for 20 minutes | `xcodegen generate` after new files |
| **Kept guessing** | Same error 4 times. Finally checked apple-docs MCP. | Stop at 2, investigate |
| **Deleted "unused" file** | Periphery said unused, but ServiceContainer needed it | Grep before delete |
| **Wrong bundle ID** | Used `.dev` in release context, broke signing | Check bundle ID table below |
| **tccutil on wrong ID** | Reset permissions for production bundle | NEVER reset `.app` bundle |

**The #1 differentiator**: Skimming this SOP = 5/10 sessions. Internalizing it = 8+/10.

**"If you skim you sin."** - The answers are here. Read them.

---

## Bundle IDs - DO NOT CONFUSE

| Config | Bundle ID | Use |
|--------|-----------|-----|
| **Debug** | `com.saneclip.dev` | Local testing ONLY |
| **Release** | `com.saneclip.app` | Production/users |

**NEVER:**
- Run `tccutil reset` against `.app` bundle ID
- Put `.dev` bundle ID in release scripts or shipped code
- Confuse which is which during releases

---

## Quick Start for AI Agents

**New to this project? Start here:**

1. **Read Rule #0 first** (Section "The Rules") - It's about HOW to use all other rules
2. **All files stay in project** - NEVER write files outside `~/SaneApps/apps/SaneClip/` unless user explicitly requests it
3. **Use SaneMaster for builds/tests** - never raw `xcodebuild`
4. **Self-rate after every task** - Rate yourself 1-10 on SOP adherence (see Self-Rating section)

**Key Commands:**
```bash
xcodegen generate              # After creating new files
./scripts/SaneMaster.rb verify # Build + tests
./scripts/SaneMaster.rb test_mode  # Build + launch + logs
./scripts/SaneMaster.rb logs --follow
```

---

## The Rules

### #0: NAME THE RULE BEFORE YOU CODE

DO: State which rules apply before writing code
DON'T: Start coding without thinking about rules

```
RIGHT: "Uses Apple API -> Rule #2: VERIFY BEFORE YOU TRY"
RIGHT: "New file -> Rule #9: NEW FILE? GEN THAT PILE"
WRONG: "Let me just code this real quick..."
```

### #1: STAY IN YOUR LANE

DO: Save all files inside `~/SaneApps/apps/SaneClip/`
DON'T: Create files outside project without asking

### #2: VERIFY BEFORE YOU TRY

DO: Verify API exists before using (apple-docs MCP, context7 MCP)
DON'T: Assume an API exists from memory or web search

### #3: TWO STRIKES? INVESTIGATE

DO: After 2 failures -> stop, follow **Research Protocol** (see section below)
DON'T: Guess a third time without researching

### #4: GREEN MEANS GO

DO: Fix all test failures before claiming done
DON'T: Ship with failing tests

### #5: USE PROJECT TOOLS

DO: Use `xcodegen generate` after new files, then `./scripts/SaneMaster.rb verify`
DON'T: Use raw xcodebuild without understanding project config

### #6: BUILD, KILL, LAUNCH, LOG

DO: Run full sequence after every code change
DON'T: Skip steps or assume it works

```bash
./scripts/SaneMaster.rb test_mode  # Kill → Build → Launch → Logs
```

### #7: NO TEST? NO REST

DO: Every bug fix gets a test that verifies the fix
DON'T: Use placeholder or tautology assertions (`#expect(true)`)

### #8: BUG FOUND? WRITE IT DOWN

DO: Document bugs in TodoWrite immediately
DON'T: Try to remember bugs or skip documentation

### #9: NEW FILE? GEN THAT PILE

DO: Run `xcodegen generate` after creating any new file
DON'T: Create files without updating project

### #10: FIVE HUNDRED'S FINE, EIGHT'S THE LINE

| Lines | Status |
|-------|--------|
| <500 | Good |
| 500-800 | OK if single responsibility |
| >800 | Must split |

### #11: TOOL BROKE? FIX THE YOKE

DO: If build tools fail, fix the tool/config
DON'T: Work around broken tools

### #12: TALK WHILE I WALK

DO: Use subagents for heavy lifting, stay responsive to user
DON'T: Block on long operations

---

## Self-Rating (MANDATORY)

After each task, rate yourself. Format:

```
**Self-rating: 7/10**
Verified API via apple-docs, ran full build cycle
Forgot to run xcodegen after new file
```

| Score | Meaning |
|-------|---------|
| 9-10 | All rules followed |
| 7-8 | Minor miss |
| 5-6 | Notable gaps |
| 1-4 | Multiple violations |

---

## Research Protocol (STANDARD)

This is the standard protocol for investigating problems. Used by Rule #3, Circuit Breaker, and any time you're stuck.

### Tools to Use (ALL of them)

| Tool | Purpose | When to Use |
|------|---------|-------------|
| **Task agents** | Explore codebase, analyze patterns | "Where is X used?", "How does Y work?" |
| **apple-docs MCP** | Verify Apple APIs exist and usage | Any Apple framework API |
| **context7 MCP** | Library documentation | Third-party packages (KeyboardShortcuts, Sparkle) |
| **WebSearch/WebFetch** | Solutions, patterns, best practices | Error messages, architectural questions |
| **Grep/Glob/Read** | Local investigation | Find similar patterns, check implementations |
| **memory MCP** | Past bug patterns, architecture decisions | "Have we seen this before?" |

### Memory MCP Usage

```
# Project-scoped searches
mcp__plugin_claude-mem_mcp-search__search query: "clipboard" project: "SaneClip"
```

### Research Output -> Plan

After research, present findings in this format:

```
## Research Findings

### What I Found
- [Tool used]: [What it revealed]
- [Tool used]: [What it revealed]

### Root Cause
[Clear explanation of why the problem occurs]

### Proposed Fix

[Rule #X: NAME] - specific action
[Rule #Y: NAME] - specific action
...

### Verification
- [ ] ./scripts/SaneMaster.rb verify passes
- [ ] Manual test: [specific check]
```

---

## Circuit Breaker Protocol

The circuit breaker is an automated safety mechanism that **blocks Edit/Bash/Write tools** after repeated failures.

### When It Triggers

| Condition | Threshold | Meaning |
|-----------|-----------|---------|
| **Same error 3x** | 3 identical | Stuck in loop, repeating same mistake |
| **Total failures** | 5 any errors | Flailing, time to step back |

### Recovery Flow

```
CIRCUIT BREAKER TRIPS
         |
         v
┌─────────────────────────────────────────────┐
│  1. READ ERRORS                             │
│     - What failed? What pattern?            │
├─────────────────────────────────────────────┤
│  2. RESEARCH (use ALL tools above)          │
│     - What API am I misusing?               │
│     - Has this bug pattern happened before? │
│     - What does the documentation say?      │
├─────────────────────────────────────────────┤
│  3. PRESENT SOP-COMPLIANT PLAN              │
│     - State which rules apply               │
│     - Show what research revealed           │
│     - Propose specific fix steps            │
├─────────────────────────────────────────────┤
│  4. USER APPROVES PLAN                      │
└─────────────────────────────────────────────┘
         |
         v
    EXECUTE APPROVED PLAN
```

**Key insight**: Being blocked is not failure - it's the system working. The research phase often reveals the root cause that guessing would never find.

---

## Plan Format (MANDATORY)

Every plan must cite which rule justifies each step. No exceptions.

**Format**: `[Rule #X: NAME] - specific action with file:line or command`

### DISAPPROVED PLAN

```
## Plan: Fix Bug

### Steps
1. Clean build
2. Fix the issue
3. Rebuild and verify

Approve?
```

**Why rejected:**
- No `[Rule #X]` citations - can't verify SOP compliance
- No tests specified (violates Rule #7)
- Vague "fix" without file:line references

### APPROVED PLAN

```
## Plan: Fix [Bug Description]

### Bugs to Fix
| Bug | File:Line | Root Cause |
|-----|-----------|------------|
| [Description] | [File.swift:50] | [Root cause] |

### Steps

[Rule #5: USE PROJECT TOOLS] - `xcodegen generate` if new files

[Rule #7: TESTS FOR FIXES] - Create tests:
  - Tests/[TestFile].swift: `test[FeatureName]()`

[Rule #6: FULL CYCLE] - Verify fixes:
  - `./scripts/SaneMaster.rb verify`
  - `./scripts/SaneMaster.rb test_mode`
  - Manual: [specific check]

[Rule #4: GREEN BEFORE DONE] - All tests pass before claiming complete

Approve?
```

---

## Project Structure

```
SaneClip/
├── SaneClipApp.swift       # Main app with AppDelegate, ClipboardManager, ClipboardItem
├── main.swift              # App entry point
├── Core/
│   ├── ClipboardManager.swift  # Clipboard monitoring and history
│   ├── SettingsModel.swift     # User preferences
│   ├── TextTransformService.swift  # Text transformations (UPPERCASE, lowercase, etc.)
│   ├── BrandColors.swift       # Sane Apps brand color palette
│   └── Models/                 # Data models (ClipboardItem, SavedClipboardItem)
├── UI/
│   ├── Settings/           # SettingsView, SettingsModel
│   └── Onboarding/         # OnboardingView
├── Resources/              # Assets, entitlements
├── Tests/                  # Unit tests (Swift Testing: @Test, #expect)
├── scripts/                # Build automation scripts
├── docs/                   # Cloudflare Pages website
└── project.yml             # XcodeGen configuration
```

## Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| ClipboardManager | Core/ClipboardManager.swift | Monitors pasteboard, manages history, paste stack |
| TextTransformService | Core/TextTransformService.swift | Text transforms (UPPERCASE, lowercase, titleCase) |
| ClipboardItem | Core/Models/ClipboardItem.swift | Individual clipboard entry model |
| SettingsModel | Core/SettingsModel.swift | User preferences persistence |
| AppDelegate | SaneClipApp.swift | Menu bar setup, popover management |
| SettingsView | UI/Settings/SettingsView.swift | Settings window UI |
| OnboardingView | UI/Onboarding/OnboardingView.swift | First-launch wizard |

## Menu Bar App Notes

- **LSUIElement: true** - No dock icon, menu bar only
- Uses NSPopover for clipboard history panel
- Keyboard shortcuts via KeyboardShortcuts package

## UI Testing

This is a **menu bar app**. Use `macos-automator` MCP for UI testing:

```
mcp__macos-automator__get_scripting_tips search_term: "menu bar"
mcp__macos-automator__execute_script kb_script_id: "..."
```

Use SaneMaster for macOS builds/tests. XcodeBuildMCP simulator tools are iOS-only.

## Dependencies

| Package | Purpose |
|---------|---------|
| KeyboardShortcuts | Global hotkey support |
| Sparkle | Auto-update framework |

---

## Where to Look First

| Need | Check |
|------|-------|
| Build/test commands | `./scripts/SaneMaster.rb verify` |
| Project structure | `project.yml` (XcodeGen config) |
| Past bugs/learnings | Sane-Mem MCP: `mcp__plugin_claude-mem_mcp-search__search` |
| Touch ID/security | `Core/ClipboardManager.swift` (authentication logic) |
| Clipboard logic | `Core/ClipboardManager.swift` |
| UI components | `UI/` directory |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "File not found" after new file | `xcodegen generate` |
| Build errors after merge | `xcodegen generate` then clean build |
| Tests failing mysteriously | Clean derived data, rebuild |
| Menu bar not appearing | Check LSUIElement in Info.plist |
| Touch ID not prompting | Check entitlements file |
| Wrong bundle ID errors | Check Debug vs Release config |

---

## Release Process

```bash
# 1. Build, sign, notarize, create DMG (unified SaneProcess script)
./scripts/SaneMaster.rb release

# 2. Upload DMG to Cloudflare R2 (the only hosted DMG)
npx wrangler r2 object put sanebar-downloads/SaneClip-X.Y.Z.dmg \
  --file=releases/SaneClip-X.Y.Z.dmg --content-type="application/octet-stream" --remote

# 3. Update appcast.xml (Sparkle)
# (Use the project-specific post-release process if present)
```

**Remember:** Release uses `com.saneclip.app` bundle ID. Debug uses `com.saneclip.dev`.
**Note:** We do NOT host DMGs on GitHub Releases. Cloudflare R2 + `dist.saneclip.com` is the source of truth.
