# SaneClip

<p align="center">
  <img src="docs/images/screenshot-popover.png" alt="SaneClip Screenshot" width="400">
</p>

<p align="center">
  <strong>A powerful clipboard manager for macOS with Touch ID protection, smart snippets, and iCloud sync.</strong>
</p>

<p align="center">
  <a href="https://saneclip.com">Website</a> •
  <a href="#installation">Install</a> •
  <a href="#features">Features</a> •
  <a href="#automation">Automation</a> •
  <a href="ROADMAP.md">Roadmap</a> •
  <a href="CONTRIBUTING.md">Contribute</a>
</p>

---

## Features

### Core Features

#### 🔐 Touch ID Protection
Lock your clipboard history behind biometrics. 30-second grace period means no repeated prompts.

#### ⌨️ Keyboard-First Design
- **⌘⇧V** — Open clipboard history
- **⌘⌃1-9** — Paste items 1-9 instantly
- **⌘⇧⌥V** — Paste as plain text
- **⌘⌃V** — Paste from stack (queue mode)
- **↑↓ or j/k** — Navigate through history

#### 📌 Pin Favorites
Keep frequently-used text always accessible. Pinned items never expire. Drag to reorder your pins.

#### 🔍 Instant Search with Filters
Filter your entire clipboard history as you type. Advanced filtering by:
- **Date range** — Today, Last 7 Days, Last 30 Days, All Time
- **Content type** — Text, Links, Code, Images
- **Source app** — Filter by originating application

#### 📱 App Source Attribution
See which app each clip came from with its icon. Know if that text came from Slack, VS Code, or Safari.

---

### Smart Snippets

Create reusable text templates with dynamic placeholders:

```
Hello {{name}},

Thank you for your {{reason}}.
Today's date is {{date}}.

Best regards,
{{clipboard}}
```

**Built-in placeholders:**
- `{{name}}` — Prompts for input when pasting
- `{{date}}` — Auto-fills current date
- `{{time}}` — Auto-fills current time
- `{{clipboard}}` — Current clipboard content

Manage snippets in Settings → Snippets. Paste via URL scheme or Shortcuts app.

---

### Text Transforms

Right-click any text item and choose "Paste As..." to transform before pasting:

| Transform | Description |
|-----------|-------------|
| UPPERCASE | Convert to all caps |
| lowercase | Convert to all lowercase |
| Title Case | Capitalize each word |
| Trimmed | Remove leading/trailing whitespace |
| Reverse Lines | Reverse order of lines |
| JSON Pretty Print | Format JSON with indentation |
| Strip HTML | Remove HTML tags, keep text |
| Markdown to Plain | Strip markdown formatting |

---

### Clipboard Rules

Automatic processing applied to every copy:

| Rule | Description |
|------|-------------|
| Strip URL Tracking | Removes utm_*, fbclid, gclid, etc. from URLs |
| Auto-Trim Whitespace | Remove leading/trailing whitespace |
| Lowercase URLs | Convert URLs to lowercase |
| Normalize Line Endings | Convert to consistent line breaks |
| Remove Duplicate Spaces | Collapse multiple spaces |

Configure rules in Settings → General.

---

### Privacy & Security

#### 🛡️ Sensitive Data Detection
Automatically detects and flags sensitive content:
- **Credit cards** — Validates with Luhn algorithm
- **Social Security Numbers** — XXX-XX-XXXX patterns
- **API keys** — OpenAI, AWS, GitHub, Slack, Stripe, Google, and more
- **Passwords** — Common password field patterns
- **Private keys** — SSH, PGP/GPG keys
- **Email addresses** — Standard email patterns

#### 🔒 Auto-Purge Rules
Configure automatic deletion of sensitive items after a set time (1 minute, 5 minutes, 1 hour).

#### 🔐 End-to-End Encryption
All synced data is encrypted with AES-256-GCM before leaving your device. Keys stored in macOS Keychain.

#### 🚫 Password Manager Protection
Detects transient clipboard types (1Password, Dashlane, etc.) and blocks them from history.

#### 📵 Excluded Apps
Block sensitive apps from clipboard capture entirely.

---

### iCloud Sync

Sync your clipboard history across all your Macs:

- **End-to-end encrypted** — Data encrypted before upload
- **Real-time sync** — Push notifications for instant updates
- **Conflict resolution** — Last-write-wins with device tracking
- **Selective sync** — Only syncs when enabled

Enable in Settings → Sync. Requires iCloud account.

---

### Organization

- **Duplicate detection** — Identical clips automatically consolidate
- **Paste count badges** — Track how many times you've used each item
- **Compact timestamps** — See "2h" or "3d" instead of verbose dates
- **Paste Stack** — Queue items for sequential pasting (FIFO)
- **Auto-Expire** — Delete old items after 1h, 24h, 7d, or 30d (pinned items preserved)

---

### macOS Widgets

Add SaneClip widgets to your desktop or Notification Center for quick access:

| Widget | Sizes | Description |
|--------|-------|-------------|
| **Recent Clips** | Small, Medium | Shows your 3-5 most recent clipboard items |
| **Pinned Clips** | Small, Medium | Quick access to your pinned favorites |

Widgets automatically update when you copy new content. Add via right-click desktop → Edit Widgets → SaneClip.

---

### Data Management

#### 📤 Export History
Export your entire clipboard history to JSON. Includes timestamps, paste counts, and source app info.

#### 📥 Import History
Import previously exported history. Merge with existing or replace entirely.

#### ⚙️ Settings Sync
Export/import your settings configuration for backup or transfer to another Mac.

#### 📊 Storage Stats
View detailed statistics about your clipboard history:
- Total items and pinned count
- Storage size on disk
- Items by content type breakdown

---

## Automation

### URL Scheme

Control SaneClip programmatically via `saneclip://` URLs:

| URL | Action |
|-----|--------|
| `saneclip://paste?index=0` | Paste item at index |
| `saneclip://search?q=keyword` | Open search with query |
| `saneclip://snippet?name=MySnippet` | Paste snippet by name |
| `saneclip://copy?text=Hello` | Copy text to clipboard |
| `saneclip://history` | Show history window |
| `saneclip://export` | Trigger history export |
| `saneclip://sync` | Trigger iCloud sync |
| `saneclip://clear` | Clear history (with confirmation) |

### Siri Shortcuts

SaneClip integrates with Shortcuts.app via App Intents:

| Intent | Description |
|--------|-------------|
| Get Clipboard History | Returns recent text items |
| Paste Clipboard Item | Pastes item at specified index |
| Search Clipboard | Search history and return matches |
| Copy to SaneClip | Copy text to clipboard |
| Clear Clipboard History | Clear all non-pinned items |
| Paste Snippet | Paste a saved snippet by name |
| List Snippets | Returns all snippet names |

Use these in Shortcuts.app or trigger via Siri voice commands.

### Webhooks

Send HTTP notifications when clipboard events occur:

- **Events:** Copy, Paste, Delete, Clear
- **HMAC-SHA256 signatures** for security
- **Retry logic** with exponential backoff
- **Content inclusion** optional (for text items)

Configure in Settings → Webhooks (coming soon in UI).

---

## Installation

Download the latest DMG from [saneclip.com](https://saneclip.com) — **$5 one-time, free updates for life.**

---

## Requirements

- **macOS 15.0** (Sequoia) or later
- Apple Silicon Mac (M1+)

---

## Privacy

SaneClip is **privacy-first**:

- ✅ All data stays on your Mac (unless iCloud sync enabled)
- ✅ E2E encryption for all synced data
- ✅ No analytics or telemetry
- ✅ Open source — verify yourself

See [PRIVACY.md](PRIVACY.md) for details.

---

## Documentation

| Document | Purpose |
|----------|---------|
| [ROADMAP.md](ROADMAP.md) | Feature plans and timeline |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |
| [DEVELOPMENT.md](DEVELOPMENT.md) | Development setup and guidelines |
| [CHANGELOG.md](CHANGELOG.md) | Version history |
| [SECURITY.md](SECURITY.md) | Security policy |
| [PRIVACY.md](PRIVACY.md) | Privacy practices |

---

## Development

```bash
# Clone the repo
git clone https://github.com/sane-apps/SaneClip.git
cd SaneClip

# Generate Xcode project (requires XcodeGen)
xcodegen generate

# Open in Xcode
open SaneClip.xcodeproj

# Build and run
⌘R
```

See [DEVELOPMENT.md](DEVELOPMENT.md) for detailed setup and [CONTRIBUTING.md](CONTRIBUTING.md) for coding standards.

---

## Support

- 🐛 [Report a Bug](https://github.com/sane-apps/SaneClip/issues/new?template=bug_report.md)
- 💡 [Request a Feature](https://github.com/sane-apps/SaneClip/issues/new?template=feature_request.md)
- ❤️ [Sponsor on GitHub](https://github.com/sponsors/sane-apps)

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
  Made with ❤️ by <a href="https://github.com/sane-apps">Mr. Sane</a>
</p>
