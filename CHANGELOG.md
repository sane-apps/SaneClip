# Changelog

All notable changes to SaneClip will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

---

## [1.0.1] - 2026-01-18

### Fixed
- **Touch ID unlock loop** — Using Touch ID no longer closes the clipboard history. Added 30-second grace period so you stay authenticated between accesses.
- **Smoother popover after auth** — Added slight delay for Touch ID dialog to fully dismiss before showing clipboard.

### Changed
- **Broader compatibility** — Now supports macOS 14 Sonoma and later (was Sequoia-only). All Apple Silicon Macs supported: M1, M2, M3, M4.
- **Updated website** — New saneclip.com with improved Open Graph previews.

---

## [1.0.0] - 2026-01-17

### Added
- **Clipboard history** — Automatically captures everything you copy
- **Touch ID protection** — Optional biometric lock for clipboard access
- **Keyboard shortcuts** — ⌘⇧V for history, ⌘⌃1-9 for quick paste
- **Paste as plain text** — ⌘⇧⌥V strips formatting
- **Pin favorites** — Keep important clips always accessible
- **Search** — Filter history by content
- **Password protection** — Auto-removes quick-cleared items (password managers)
- **Settings** — Configurable history size, Touch ID, keyboard shortcuts
- **Auto-updates** — Sparkle integration for seamless updates
- **Launch at login** — Optional startup on login

### Technical
- Native SwiftUI app for macOS
- Hardened runtime with notarization
- Open source on GitHub

---

## [Unreleased]

### Planned for v1.1
- App source attribution (show which app clips came from)
- Exclude apps list (blacklist password managers, etc.)
- Keyboard navigation in history list
- See [ROADMAP.md](ROADMAP.md) for full plans
