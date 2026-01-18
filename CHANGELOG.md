# Changelog

All notable changes to SaneClip will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

---

## [1.1] - 2026-01-18

### Added
- **First-launch onboarding** — Welcome tutorial with permissions setup and keyboard shortcuts guide
- **App source attribution** — See which app each clip came from with app icon
- **Excluded apps list** — Block sensitive apps (1Password, banking apps) from clipboard capture
- **Duplicate detection** — Automatically consolidate identical clips
- **Keyboard navigation** — Arrow keys and vim-style j/k navigation in history
- **Paste count badges** — Track how many times each item was pasted
- **Menu bar icon options** — Choose between List and Minimal icon styles
- **Sound effects toggle** — Optional paste confirmation sounds (opt-in)

### Changed
- **Security-by-default** — Authentication now required to reduce any security setting
- **Smarter time display** — Compact format (41s → 15m → 2h → 3d)
- **Compact stats** — Shows "21w · 350c" instead of verbose text
- **Aligned metadata** — Fixed-width columns for cleaner visual scanning
- **Renamed setting** — "Protect passwords" → "Detect & skip passwords" for clarity

### Fixed
- **Metadata no longer wraps** — Single-line metadata regardless of content length

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

### Planned for v1.5
- Multiple paste modes (plain text, UPPERCASE, lowercase, Title Case)
- Smart snippets with placeholders
- Rich search filters
- See [ROADMAP.md](ROADMAP.md) for full plans
