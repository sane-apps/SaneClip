# SaneClip

<p align="center">
  <img src="docs/images/screenshot-popover.png" alt="SaneClip Screenshot" width="400">
</p>

<p align="center">
  <strong>A beautiful clipboard manager for macOS with Touch ID protection.</strong>
</p>

<p align="center">
  <a href="https://saneclip.com">Website</a> •
  <a href="#installation">Install</a> •
  <a href="#features">Features</a> •
  <a href="ROADMAP.md">Roadmap</a> •
  <a href="CONTRIBUTING.md">Contribute</a>
</p>

---

## Features

### 🔐 Touch ID Protection
Lock your clipboard history behind biometrics. 30-second grace period means no repeated prompts.

### ⌨️ Keyboard-First Design
- **⌘⇧V** — Open clipboard history
- **⌘⌃1-9** — Paste items 1-9 instantly
- **⌘⇧⌥V** — Paste as plain text
- **↑↓ or j/k** — Navigate through history

### 📌 Pin Favorites
Keep frequently-used text always accessible. Pinned items never expire.

### 🔍 Instant Search
Filter your entire clipboard history as you type.

### 🛡️ Privacy & Security
- **Password protection** — Detects transient clipboard types (1Password, Dashlane, etc.) and blocks them
- **Excluded apps** — Block sensitive apps from clipboard capture entirely
- **Touch ID** — Require authentication to view history
- **Encrypted storage** — History file uses macOS file protection

### 📱 App Source Attribution
See which app each clip came from with its icon. Know if that text came from Slack, VS Code, or Safari.

### 🔢 Smart Organization
- **Duplicate detection** — Identical clips automatically consolidate
- **Paste count badges** — Track how many times you've used each item
- **Compact timestamps** — See "2h" or "3d" instead of verbose dates
- **URL tracking stripping** — Auto-removes utm_*, fbclid, gclid from copied URLs

### ⚙️ Customization
- **Menu bar icon styles** — Choose between List or Minimal
- **Sound effects** — Optional audio feedback when copying
- **History size** — Control how many clips to keep

### 🎨 Native macOS Design
Built with SwiftUI. Glass material effects, hover highlighting, and content-type icons. Looks right at home on Sequoia and beyond. Auto-updates via Sparkle.

### 🖱️ Click to Paste
Single-click any item to paste instantly. Right-click for more options (Pin, Delete, Paste as Plain Text).

---

## Installation

### Direct Download (Recommended)

Download the latest DMG from [saneclip.com](https://saneclip.com) — **$5 one-time, free updates for life.**

### Homebrew

```bash
brew install stephanjoseph/saneclip/saneclip
```

---

## Requirements

- **macOS 15.0** (Sequoia) or later
- Apple Silicon Mac (M1+)

---

## Privacy

SaneClip is **privacy-first**:

- ✅ All data stays on your Mac
- ✅ No analytics or telemetry
- ✅ Open source — verify yourself

See [PRIVACY.md](PRIVACY.md) for details.

---

## Documentation

| Document | Purpose |
|----------|---------|
| [ROADMAP.md](ROADMAP.md) | Feature plans and timeline |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |
| [CHANGELOG.md](CHANGELOG.md) | Version history |
| [SECURITY.md](SECURITY.md) | Security policy |
| [PRIVACY.md](PRIVACY.md) | Privacy practices |

---

## Development

```bash
# Clone the repo
git clone https://github.com/stephanjoseph/SaneClip.git
cd SaneClip

# Open in Xcode
open SaneClip.xcodeproj

# Build and run
⌘R
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for coding standards.

---

## Support

- 🐛 [Report a Bug](https://github.com/stephanjoseph/SaneClip/issues/new?template=bug_report.md)
- 💡 [Request a Feature](https://github.com/stephanjoseph/SaneClip/issues/new?template=feature_request.md)
- ❤️ [Sponsor on GitHub](https://github.com/sponsors/stephanjoseph)

### Crypto

| Currency | Address |
|----------|---------|
| BTC | `3Go9nJu3dj2qaa4EAYXrTsTf5AnhcrPQke` |
| SOL | `FBvU83GUmwEYk3HMwZh3GBorGvrVVWSPb8VLCKeLiWZZ` |
| ZEC | `t1PaQ7LSoRDVvXLaQTWmy5tKUAiKxuE9hBN` |

---

## License

MIT — see [LICENSE](LICENSE) for details.

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/stephanjoseph">Mr. Sane</a>
</p>
