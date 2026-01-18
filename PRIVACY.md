# Privacy Policy

**Effective Date:** January 2026
**Last Updated:** January 2026

## The Short Version

SaneClip is **privacy-first by design**:

- ✅ All data stays on your Mac
- ✅ No cloud sync (yet)
- ✅ No analytics or telemetry
- ✅ No account required
- ✅ Open source — verify yourself

---

## What Data SaneClip Collects

### Clipboard History
- **What**: Text and images you copy
- **Where**: Stored locally in `~/Library/Application Support/SaneClip/`
- **Retention**: Configurable (default: 100 items)
- **Encryption**: Not encrypted at rest (protected by macOS file permissions)

### User Preferences
- **What**: Settings like history size, Touch ID preference, keyboard shortcuts
- **Where**: macOS UserDefaults (local only)
- **Shared**: Never

### Crash Reports
- **What**: If the app crashes, macOS may collect crash logs
- **Where**: Stored locally by macOS
- **Shared**: Only if you manually submit to Apple

---

## What SaneClip Does NOT Collect

- ❌ Personal information (name, email, etc.)
- ❌ Usage analytics
- ❌ Keystroke logging
- ❌ Screenshots
- ❌ Any data sent to remote servers

---

## Third-Party Services

### Sparkle (Auto-Updates)
- SaneClip uses [Sparkle](https://sparkle-project.org/) for updates
- Sparkle checks `https://github.com/stephanjoseph/SaneClip/` for updates
- No personal data is transmitted — only app version

### Lemon Squeezy (Payments)
- If you purchase SaneClip, payment is handled by [Lemon Squeezy](https://lemonsqueezy.com/)
- We do not receive or store payment details
- See Lemon Squeezy's privacy policy for their practices

---

## Password Manager Protection

SaneClip includes optional protection for password managers:

- Detects "quick-clear" patterns (copy then clear within 3 seconds)
- Automatically removes these entries from history
- Designed to prevent accidental storage of passwords

**Important**: This is a best-effort feature, not a security guarantee. For sensitive credentials, use a dedicated password manager.

---

## Your Rights

Since all data is stored locally, you have full control:

- **Access**: View all data in `~/Library/Application Support/SaneClip/`
- **Delete**: Clear history anytime via the app, or delete the folder
- **Export**: Coming in a future version

---

## Children's Privacy

SaneClip does not knowingly collect data from children under 13. The app does not require any account or personal information.

---

## Changes to This Policy

We may update this policy occasionally. Changes will be noted with a new "Last Updated" date. For significant changes, we'll include a notice in the app's release notes.

---

## Contact

Questions about privacy?

- GitHub: [github.com/stephanjoseph/SaneClip](https://github.com/stephanjoseph/SaneClip)
- Email: [privacy@saneapps.com](mailto:privacy@saneapps.com)

---

## Open Source Transparency

SaneClip is open source. You can verify our privacy claims by reviewing the code:

```bash
git clone https://github.com/stephanjoseph/SaneClip.git
# Search for network calls — you won't find any (except Sparkle updates)
grep -r "URLSession\|URLRequest\|Network" SaneClip/
```
