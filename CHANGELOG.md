# Changelog

All notable changes to SaneClip will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

---

## [2.3.14] - Unreleased

- The Pro Paste Stack can now build itself as you copy: turn on "Record copies" (in the stack panel, or Edit ▸ Record Copies to Paste Stack / ⌘⇧R) and everything you copy is added to the stack in order, ready to paste back one after another. It stays a fully editable, reorderable list, and is capped so it can't grow forever.
- History rows now show which app each clip came from, right next to when it was copied ("Safari · 2m ago"), instead of leading with a word and character count. The count is still there on hover.
- The Pro floating history window now opens a live preview beside the list when it's wide enough: the full clip plus its source app, type, when it was captured, how often it's been pasted, and its collection, tags, and note — with Paste, Plain Text, and Pin right there.
- The empty history window now keeps the search field at the top instead of floating it into the middle.
- Colors in the history window now follow one consistent meaning each: blue for actions, amber for pinned, green for pasted, yellow for Pro, teal for merge, and violet for the paste stack — so a color always tells you the same thing.
- The bottom of the history window is now a fixed bar — item count on the left, Settings and Smart Clear on the right, always in the same place — with merge and paste-stack controls appearing in a band just above it only when you're using them.
- Routine "you're up to date" update checks no longer show up as errors in diagnostics.
- The bottom toolbar collapses to a single clean row when there's nothing queued, instead of showing an empty paste-stack chip.
- Moves the merge queue and paste stack controls to their own footer row, so the horizontal scrollbar can no longer cover `Clear Queue` at narrow widths.
- Fixes the Pro floating history window closing when you click its own title bar, search field, filter, or pause controls; only clicks truly outside the window close it now.
- Adds a Pro pin button beside history search to keep the history window open after pasting — and the setting (renamed "Keep history window open after pasting") now also applies to normal history pastes, not just the paste stack.
- Keeps the floating history window (and your in-progress edit) open while an Edit, Smart Clear, or preview sheet is showing, even when the sheet extends past the window edge at small window sizes.

---

## [2.3.13] - 2026-07-02

- Keeps Edit Text Save and Cancel buttons visible while editing long clips.
- Makes Clipboard Rules switches update visibly as soon as they are clicked.
- Keeps the resizable floating history window correctly Pro-gated and closes it when you click outside it.
- Known issues, fixed in 2.3.14: the footer scrollbar could still cover `Clear Queue`, and clicks on the floating window's own title/search/filter/pause area wrongly closed it.

---

## [2.3.12] - 2026-07-01

A big history + window update:

- Clipboard history can now open as a free-floating, resizable window (Settings → General → Appearance → "Open history as a resizable floating window") that remembers its last size and screen position between launches.
- Drag clips straight out of the window into other apps (a subtle handle appears on hover); pinned items keep drag-to-reorder.
- Faster keyboard control: the selection now scrolls into view as you move, with Home/End and Page Up/Down to jump, `P` to pin the selected clip, and `Esc` to clear search/filters or close the window.
- Layout is solid at every size now — the bottom toolbar and the filter row no longer squash or clip on narrow widths, and clip badges stay visible.
- Quick-paste (⌘⌃1–9) hints now only show when they're accurate.
- History rows are now color-coded by source app for *every* app (Mac and iPhone/iPad), not just Apple apps — each source gets its own consistent color instead of everything defaulting to blue.

---

## [2.3.11] - 2026-06-22

Pro is now free to try for 14 days. Basic remains included after the trial.

---

## [2.3.10] - 2026-06-22

Pro is now free to try for 14 days. Basic remains included after the trial.

---

## [2.3.9] - 2026-06-06

Restores the visible iPhone clipboard save prompt, improves multi-clip paste saving, adds a Mac menu bar icon visibility setting that preserves app access, and updates Setapp/App Store signing readiness.

---

## [2.3.9] - 2026-06-06

Adds a Mac setting to hide the SaneClip menu bar icon while preserving at least one app entry point, and tightens the Setapp build entitlements by removing unused Apple Events and Sparkle review surface.

---

## [2.3.8] - 2026-06-06

Restores the visible iPhone clipboard save prompt, saves every current iOS pasteboard item SaneClip can access, improves image sharing, and aligns automation/privacy support copy with the shipped Mac and iPhone workflows.

---

## [2.3.8] - 2026-06-06

Restores the visible iPhone clipboard save prompt, saves every current pasteboard item iOS exposes, and clarifies that iPhone/iPad use explicit save, Share sheet, Shortcuts, and iCloud companion flows rather than silent background clipboard capture.
Fixes iOS share extension image availability and keeps synced CloudKit uploads aligned with the History Encryption setting.
Tightens public automation and privacy copy so customer-facing claims match the shipped URL scheme, App Intents, Shortcuts, and support flows.

---

## [2.3.7] - 2026-06-04

Keeps synced Mac clipboard text appearing on iPhone and iPad automatically while the companion app is foregrounded, without showing the local pasteboard save banner for iCloud-synced clips.
Improves settings and history-window structure without changing the customer workflow.

---

## [2.3.6] - 2026-05-21

Improves password protection so generated passwords copied from browser extensions are skipped when Protect Passwords is enabled.

---

## [2.3.5] - 2026-05-19

Fixes license-key paste reliability in activation and settings.

---

## [2.3.4] - 2026-05-12

Fixes Capture Text after the macOS screen picker and moves clipboard history to Cmd-Shift-Control-Y.

---

## [2.3.4] - 2026-05-12

Fixes Capture Text after the macOS screen picker by capturing the selected content through the picker-backed ScreenCaptureKit stream path instead of the still-image API path that could loop back into Screen Recording/TCC failures.
Migrates the unreliable legacy Command-Shift-V clipboard-history shortcut to Command-Shift-Control-Y and updates reset/docs copy to match.

---

## [2.3.3] - 2026-05-09

Improves startup reliability on macOS 15, fixes clipboard edit-save behavior, restores shortcut reset and snippet visibility fixes, and keeps App Store builds aligned with Apple review requirements.

---

## [2.3.2] - 2026-05-09

Fixes editing saved clipboard items, clarifies Capture Text from Screen permissions, adds visible snippet paste controls, and adds a reset action for the clipboard history shortcut.

---

## [2.3.1] - 2026-05-09

Fixes editing saved clipboard items, clarifies Capture Text from Screen permissions, adds visible snippet paste controls, and adds a reset action for the clipboard history shortcut.

---

## [2.3.0] - 2026-04-25

Adds the current direct-download and App Store release line with the refreshed Basic/Pro clipboard workflow, updated release packaging, and the latest iCloud/mobile companion polish.

---

## [2.2.15] - 2026-04-20

Makes pinning free on Mac so Basic matches the App Store promise and the iPhone companion.
Clarifies Pro upgrade messaging around organization tools while keeping advanced workflows in Pro.
Keeps the clipboard history popover pinned under the menu bar icon more reliably.
Improves the upgrade popup so license entry and dismissal behave cleanly.

---

## [2.2.14] - 2026-04-15

Aligns the Pro pricing copy across onboarding, history locks, snippets settings, and other Basic-to-Pro upgrade prompts so every upgrade surface shows the current $14.99 one-time unlock.

---

## [2.2.13] - 2026-04-09

Adds Smart Clear and true Unlimited history for Pro, restores the color-coded source indicators on iPhone and iPad, aligns the mobile UI with the approved screenshots, and improves older Mac update recovery.

---

## [2.2.13] - 2026-04-07

Restores the color-coded source indicators on iPhone and iPad, brings the mobile settings/history UI back in line with the approved App Store screenshots, and improves recovery for older Mac updater installs.

---

## [2.2.12] - 2026-04-03

Fixes iPhone iCloud sync recovery, adds manual iCloud sync reset and diagnostics, and refreshes the sync settings layout across Mac, iPhone, and iPad.

---

## [2.2.11] - 2026-03-29

Settings now use the shared SaneUI shell, the menu bar icon preview stays readable, and no-keychain builds keep the correct unlock state.

---

## [2.2.10] - 2026-03-16

Adds diagnostics-backed bug reporting on iPhone and iPad, and refreshes the latest sync and support improvements across the release line.

---

## [2.2.9] - 2026-03-11

Fixes the Excluded Apps Add App picker in sandboxed builds, restores import/export and PDF file panels, and improves keyboard navigation in history and settings.

---

## [2.2.7] - 2026-03-10

Fixes iCloud sync rollout and production schema issues, preserves local history more reliably when enabling sync, improves update reliability, and fixes edit-field keyboard shortcut handling.

---

## [2.2.6] - 2026-03-07

Improved iCloud sync bootstrap reliability across Mac, iPhone, and iPad. Fixed Excluded Apps picker behavior in Settings. Sample data now clears cleanly when real history arrives. Stability improvements.

---
## [2.2.5] - 2026-03-06

Fixes the direct-download sync release, cleans up onboarding layout, and hardens sync startup across builds.

---

## [2.2.4] - 2026-03-06

Improved iCloud sync setup across Mac, iPhone, and iPad. Fixed App Store metadata and review details. Reliability and stability improvements.

---

## [2.2.3] - 2026-03-04

Stability improvements, launch reliability hardening, and updated public feature coverage.

---

## [2.2.2] - 2026-02-27

Critical quality update: clearer onboarding, stronger permission reliability, robust Basic/Pro gating, and polished settings UX.

---

## [2.2.1] - 2026-02-27

Reliability and compatibility update. Improves license gating, update delivery, and setup stability.

---

## [2.1] - 2026-02-20

### Added
- **Secure webhook pipeline updates** — Improved validation and safer handling around webhook-triggered actions
- **Siri Shortcuts and widgets polish** — Better reliability and UX consistency across companion surfaces

### Changed
- **Update channel alignment** — Sparkle appcast now points to the 2.1 ZIP release artifact
- **Release metadata refresh** — Versioning and release notes aligned for 2.1 rollout

### Fixed
- **Stability fixes** — Multiple reliability fixes across clipboard flow and edge-case handling

---

## [2.0] - 2026-02-09

### Added
- **Cross-device sync** — iCloud-based clipboard sync between macOS and iOS
- **Smart paste modes** — Context-aware paste behavior for links, code, and standard text
- **Paste stack** — Queue-based multi-item paste workflow (FIFO/LIFO)
- **iOS companion app** — Mobile access to clipboard history with shortcuts/widgets

### Changed
- **Default paste behavior options** — Configurable default mode in settings
- **URL cleanup improvements** — Expanded tracking-parameter stripping rules

### Fixed
- **General quality improvements** — Reliability and UX refinements for history/search/paste flows

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
- See [GitHub Issues](https://github.com/sane-apps/SaneClip/issues) for full plans
