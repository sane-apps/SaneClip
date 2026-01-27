# Contributing to SaneClip

Thanks for your interest in contributing to SaneClip! This document explains how to get started.

---

## Quick Start

```bash
# Clone the repo
git clone https://github.com/sane-apps/SaneClip.git
cd SaneClip

# Open in Xcode
open SaneClip.xcodeproj

# Build and run
⌘R
```

---

## Development Environment

### Requirements

- **macOS 14.0+** (Sonoma or later)
- **Xcode 16+**
- Apple Silicon Mac (M1/M2/M3/M4)

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
3. Check the [ROADMAP.md](ROADMAP.md) for planned features

### Pull Request Process

1. **Fork** the repository
2. **Create a branch** from `main` (e.g., `feature/my-feature` or `fix/issue-123`)
3. **Make your changes** following the coding standards
4. **Test thoroughly** — especially clipboard operations and Touch ID
5. **Submit a PR** with:
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
| [ROADMAP.md](ROADMAP.md) | Feature plans |
| [SECURITY.md](SECURITY.md) | Security policy |
| [PRIVACY.md](PRIVACY.md) | Privacy practices |

---

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). Please be respectful and constructive.

---

## Questions?

- Open a [GitHub Issue](https://github.com/sane-apps/SaneClip/issues)
- Check the [Roadmap](ROADMAP.md) for feature status

Thank you for contributing!
