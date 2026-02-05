# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.2.x   | ✅ Yes             |
| 1.1.x   | ✅ Yes             |
| 1.0.x   | ✅ Yes             |
| < 1.0   | ❌ No              |

## Security Features

SaneClip includes several security features:

### Touch ID Protection
- Optional biometric authentication to access clipboard history
- 30-second grace period after authentication
- Falls back gracefully when Touch ID unavailable

### Password Manager Protection
- Detects quick-clear patterns (items copied then cleared within 3 seconds)
- Automatically removes likely password manager entries from history
- Configurable via Settings

### Local-Only Storage
- All clipboard data stored locally in `~/Library/Application Support/SaneClip/`
- 100% on-device — no cloud sync, no network calls
- No analytics or telemetry

### Hardened Runtime
- App is signed with hardened runtime
- Notarized by Apple
- No code injection vulnerabilities

## Reporting a Vulnerability

If you discover a security vulnerability, please:

1. **Do NOT** open a public GitHub issue
2. Email security concerns to: [hi@saneapps.com](mailto:hi@saneapps.com)
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial assessment**: Within 1 week
- **Fix timeline**: Depends on severity, typically 1-4 weeks

### Disclosure Policy

- We will coordinate with you on disclosure timing
- Credit will be given unless you prefer anonymity
- We aim to fix critical issues before public disclosure

## Security Best Practices for Users

1. **Enable Touch ID** if you handle sensitive data
2. **Review excluded apps** to ensure password managers are blocked
3. **Clear history** before sharing your screen
4. **Keep updated** — enable automatic updates in Settings

## Threat Model

SaneClip is designed for individual users on personal Macs. It is NOT designed for:

- Enterprise/multi-user environments (no access controls)
- Highly sensitive data (consider dedicated password managers)
- Air-gapped or compliance-regulated systems

## Dependencies

SaneClip uses these third-party dependencies:

| Package | Purpose | Security Review |
|---------|---------|-----------------|
| [Sparkle](https://sparkle-project.org/) | Auto-updates | Widely used, EdDSA signed |
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | Global hotkeys | Well-maintained |

All dependencies are pinned to specific versions.
