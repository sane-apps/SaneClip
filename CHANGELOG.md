# Changelog

All notable changes to SaneClip will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

---

## [1.4] - 2026-02-03

### Security Enhancements
- **Keychain Integration** — All secrets (webhook keys, encryption keys) now stored securely in macOS Keychain
- **History Encryption-at-Rest** — AES-256-GCM encryption for clipboard history (enabled by default)
- **URL Scheme Confirmation** — Destructive commands (copy, paste, clear) require user confirmation
- **HTTPS Enforcement** — Webhooks must use HTTPS (localhost exempt for testing)
- **Seamless Migration** — Existing plaintext data auto-migrates to encrypted format on first launch

### Technical
- New `KeychainHelper` with Sendable conformance for secure credential storage
- New `HistoryEncryption` service using CryptoKit AES-GCM
- Enhanced `URLSchemeHandler` with command parsing and confirmation requirements
- App Store sandbox keychain-access-groups entitlement added
- 22 new security tests (47 total tests, all passing)

### Testing
- URL scheme security validation
- Keychain round-trip verification
- Encryption/decryption integrity checks
- HTTPS enforcement validation

---

## [1.2] - 2026-01-25

### Removed
- **iCloud Sync** — Removed CloudKit sync infrastructure pending Apple Developer provisioning resolution
- **End-to-End Encryption** — Removed encryption service (was for sync feature)
- **Sync Settings UI** — Removed sync settings panel from preferences

### Changed
- **100% Local** — All clipboard data now stays entirely on-device
- **Simplified architecture** — Reduced complexity by removing sync-related code

### Technical
- Deleted `CloudKitSyncService.swift`, `EncryptionService.swift`, `SyncSettingsView.swift`
- Updated entitlements to remove iCloud containers
- Distribution now via Cloudflare R2 (dist.saneclip.com)

### Note
iCloud sync may return in a future version once provisioning issues are resolved. The current version is fully functional as a local-only clipboard manager.

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
- **URL tracking stripping** — Automatically removes utm_*, fbclid, gclid from copied URLs
- **Pinned items persistence** — Pinned items survive app restart
- **Hover highlighting** — Visual feedback with glass material effect on hover
- **Content-type icons** — Link, code, or text icons for faster visual scanning

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
- **Broader compatibility** — Now supports macOS 14 Sonoma and later (was Sequoia-only). All Apple Silicon Macs supported (M1+).
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
