# Contributing to SaneClip

Thanks for your interest in contributing to SaneClip! This document explains how to get started.

---

## Quick Start

```bash
# Clone the repo
git clone https://github.com/sane-apps/SaneClip.git
cd SaneClip

# Build + test (preferred)
./scripts/SaneMaster.rb verify

# Launch
./scripts/SaneMaster.rb launch
```

---

## Development Environment

### Requirements

- **macOS 14.0+** (Sonoma or later)
- **Xcode 16+**
- Apple Silicon Mac (M1/M2/M3/M4)
- **XcodeGen** (SaneMaster runs it when needed)

### Project Structure

```
SaneClip/
├── SaneClipApp.swift       # Main app, AppDelegate, ClipboardManager
├── UI/
│   └── Settings/           # Settings window views
├── docs/                   # Website (Cloudflare Pages)
├── marketing/              # Screenshots and assets
└── scripts/                # Build automation
```

---

## Coding Standards

### Swift

- **Swift 5.9+** features encouraged
- **@Observable** instead of @StateObject
- **SwiftUI** for all UI
- Keep view bodies under 50 lines — extract subviews

### Code Style

```swift
// Good: Observable class with clear state
@Observable
class SettingsModel {
    var maxHistorySize: Int = 100
    var requireTouchID: Bool = false
}

// Good: Extracted subview
struct ClipboardItemRow: View {
    let item: ClipboardItem

    var body: some View {
        // Keep it focused
    }
}
```

---

## Making Changes

### Before You Start

1. Check [GitHub Issues](https://github.com/sane-apps/SaneClip/issues) for existing discussions
2. For significant changes, open an issue first to discuss the approach
3. Check [GitHub Issues](https://github.com/sane-apps/SaneClip/issues) for planned features

### Pull Request Process

1. **Fork** the repository
2. **Create a branch** from `main` (e.g., `feature/my-feature` or `fix/issue-123`)
3. **Make your changes** following the coding standards
4. **Run tests**: `./scripts/SaneMaster.rb verify`
5. **Test thoroughly** — especially clipboard operations and Touch ID
6. **Submit a PR** with:
   - Clear description of what changed and why
   - Reference to any related issues
   - Screenshots for UI changes

### Commit Messages

Follow conventional commit format:

```
type: short description

Longer explanation if needed.

Fixes #123
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

---

## Testing

### Manual Testing Checklist

Before submitting a PR, verify:

- [ ] App launches and shows menu bar icon
- [ ] Copying text adds to history
- [ ] Pasting from history works (click and keyboard)
- [ ] Search filters history correctly
- [ ] Pin/unpin works
- [ ] Touch ID prompts when enabled
- [ ] Settings persist after restart
- [ ] No memory leaks (check Activity Monitor)

### Areas Needing Extra Care

- **Touch ID flow** — Test with biometrics enabled and disabled
- **Clipboard monitoring** — Ensure no missed copies
- **Keyboard shortcuts** — Test in various apps
- **Password protection** — Verify quick-clear items are removed

---

## Key Files

| File | Purpose |
|------|---------|
| `SaneClipApp.swift` | Main entry, AppDelegate, ClipboardManager |
| `UI/Settings/SettingsView.swift` | Settings window |
| `UI/Settings/SettingsModel.swift` | User preferences |

---

## Documentation

| Document | Purpose |
|----------|---------|
| [README.md](README.md) | User-facing overview |
| [SECURITY.md](SECURITY.md) | Security policy |
| [PRIVACY.md](PRIVACY.md) | Privacy practices |

---

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). Please be respectful and constructive.

---

## Questions?

- Open a [GitHub Issue](https://github.com/sane-apps/SaneClip/issues)
- Check [GitHub Issues](https://github.com/sane-apps/SaneClip/issues) for feature status

Thank you for contributing!

<!-- SANEAPPS_AI_CONTRIB_START -->
## Become a Contributor (Even if You Don't Code)

Are you tired of waiting on the dev to get around to fixing your problem?  
Do you have a great idea that could help everyone in the community, but think you can't do anything about it because you're not a coder?

Good news: you actually can.

Copy and paste this into Claude or Codex, then describe your bug or idea:

```text
I want to contribute to this repo, but I'm not a coder.

Repository:
https://github.com/sane-apps/SaneClip

Bug or idea:
[Describe your bug or idea here in plain English]

Please do this for me:
1) Understand and reproduce the issue (or understand the feature request).
2) Make the smallest safe fix.
3) Open a pull request to https://github.com/sane-apps/SaneClip
4) Give me the pull request link.
5) Open a GitHub issue in https://github.com/sane-apps/SaneClip/issues that includes:
   - the pull request link
   - a short summary of what changed and why
6) Also give me the exact issue link.

Important:
- Keep it focused on this one issue/idea.
- Do not make unrelated changes.
```

If needed, you can also just email the pull request link to hi@saneapps.com.

I review and test every pull request before merge.

If your PR is merged, I will publicly give you credit, and you'll have the satisfaction of knowing you helped ship a fix for everyone.
<!-- SANEAPPS_AI_CONTRIB_END -->
