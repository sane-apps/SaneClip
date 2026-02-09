# SaneClip Roadmap

## Current Version: 1.1

### ✅ Shipped
- [x] Menu bar app with clipboard icon
- [x] Clipboard history (configurable size)
- [x] Text and image support
- [x] Search/filter history
- [x] Click to paste
- [x] Keyboard shortcuts (⌘⇧V history, ⌘⌃1-9 quick paste)
- [x] Paste as plain text (⌘⇧⌥V)
- [x] Pin favorite items
- [x] Touch ID protection with 30-second grace period
- [x] Password manager protection (auto-clear quick copies)
- [x] Settings window (General, Shortcuts, About)
- [x] History persistence
- [x] Launch at login
- [x] Sparkle auto-updates
- [x] macOS Sonoma+ support (M1-M4)

---

## Phase 1: Polish (v1.1)

*Target: 2-3 weeks*

### ✅ Quick Wins (Complete)
- [x] **App source attribution** — Show which app each clip came from with icon
- [x] **Exclude apps list** — Blacklist sensitive apps (1Password, banking, etc.)
- [x] **Duplicate detection** — Auto-consolidate identical clips
- [x] **Keyboard navigation** — Arrow keys, vim-style j/k in history list
- [x] **Paste count badge** — Show how many times each item was pasted
- [x] **Security-by-default** — Auth required to reduce any security setting

### ✅ Polish (Complete)
- [x] **Improved onboarding** — First-launch tutorial
- [x] **Menu bar icon options** — List and Minimal styles
- [x] **Sound effects toggle** — Opt-in paste sounds

---

## Phase 2: Power User (v1.5)

*Target: 4-6 weeks after v1.1*

### Smart Features
- [ ] **Multiple paste modes** — Plain text, UPPERCASE, lowercase, Title Case
- [ ] **Smart snippets** — Templates with `{{placeholders}}`
- [ ] **Rich search filters** — By date range, content type, app source
- [ ] **Clipboard rules** — Auto-transform URLs, strip tracking params
- [ ] **Quick actions** — Right-click menu on clips (copy, share, edit)

### Data Management
- [ ] **Export/import history** — JSON backup and restore
- [ ] **Settings sync** — Export preferences for multiple machines
- [ ] **Configurable retention** — 7 days, 30 days, unlimited
- [ ] **Storage stats** — Show clipboard database size

---

## Phase 3: Pro Features (v2.0)

*Target: Q2 2026*

### Privacy & Security
- [ ] **Sensitive data detection** — Auto-detect credit cards, SSNs, API keys
- [ ] **Auto-purge rules** — Delete sensitive items after X minutes
- [ ] **Secure clipboard mode** — Extra protection for specific apps
- [ ] **Audit log** — Track what was copied when (optional)

### Automation
- [ ] **Shortcuts app integration** — Clipboard actions in Shortcuts
- [ ] **AppleScript support** — Scripting interface
- [ ] **Webhook triggers** — HTTP callbacks on copy events
- [ ] **URL scheme** — `saneclip://` for automation

---

## Phase 4: Team & iOS (v3.0)

*Target: Q4 2026*

### iOS Companion App
- [ ] **iPhone/iPad app** — View and search clipboard history
- [ ] **Universal clipboard enhancement** — Better than built-in
- [ ] **Widgets** — Quick access to recent/pinned clips

### Team Features
- [ ] **Shared snippets** — Team-wide templates
- [ ] **Clipboard sharing** — Send clips to teammates
- [ ] **Admin controls** — IT policy compliance

---

## Competitive Comparison

| Feature | SaneClip | Paste | Maccy | Raycast |
|---------|:--------:|:-----:|:-----:|:-------:|
| Touch ID protection | ✅ | ❌ | ❌ | ❌ |
| Native SwiftUI | ✅ | ❌ | ✅ | ❌ |
| Keyboard-first | ✅ | ❌ | ✅ | ✅ |
| Pin items | ✅ | ✅ | ❌ | ✅ |
| 100% Local | ✅ | ❌ | ✅ | ❌ |
| Open source | ✅ | ❌ | ✅ | ❌ |
| One-time purchase | ✅ | ❌ | ✅ | ❌ |
| Privacy-first | ✅ | ❌ | ✅ | ❌ |

---

## Distribution

- **Website**: [saneclip.com](https://saneclip.com)
- **Purchase**: $6.99 via Lemon Squeezy
- **Source**: [GitHub](https://github.com/sane-apps/SaneClip) (open source)
- **Updates**: Sparkle (automatic)

---

## Technical Notes

- macOS 15.0+ (Sequoia) — Apple Silicon only
- Swift 5.9+ with `@Observable`
- SwiftUI for all UI
- KeyboardShortcuts package
- Sparkle for updates
- SQLite for persistence

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to help build these features!
