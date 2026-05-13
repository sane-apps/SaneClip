# Privacy Policy

> [README](README.md) · [ARCHITECTURE](ARCHITECTURE.md) · [DEVELOPMENT](DEVELOPMENT.md) · [PRIVACY](PRIVACY.md) · [SECURITY](SECURITY.md)

**Effective Date:** March 26, 2026
**Last Updated:** May 13, 2026

SaneClip is built so your clipboard stays yours. This page explains what stays local, when the app uses the network, and why.

## The Short Version

- Your clipboard history stays on your Mac by default
- Clipboard contents are never sent to SaneApps servers
- Optional iCloud sync uses your own iCloud account between your own devices, not a SaneApps sync server
- When History Encryption is enabled, synced clipboard content is encrypted before upload and decrypted only on your devices
- Optional webhooks send data only if you set them up
- The app may send privacy-preserving aggregate operational counts, such as whether it opened in Basic or Pro, whether an upgrade button was clicked, whether a license was activated, app version, build, and update status
- No account is required

## What Stays Local

SaneClip stores the following locally on your device:

- Clipboard history
- App settings
- Touch ID and security preferences
- Excluded apps and rules

Your clipboard contents are not uploaded to SaneApps servers.

## When SaneClip Uses The Network

SaneClip uses the network only when:

- You enable iCloud sync between your own Apple devices
- You configure a webhook
- It checks for app updates
- It sends privacy-preserving aggregate counts, such as Free vs Pro launches, upgrade flow, license activation, app version, build, and update status

Those app counts do not include your clipboard contents, personal files, copied text, copied images, or synced clip data.

## What SaneClip Does Not Collect

- Your clipboard contents on SaneApps servers
- Personal files from your Mac
- Screenshots
- Keystrokes outside the clipboard items you choose to keep
- Names, email addresses, license keys, advertising identifiers, or cross-site tracking identifiers for analytics
- Data for sale to advertisers or data brokers

## Third-Party Services

SaneClip uses:

- **Sparkle** for update checks on the direct-download version
- **CloudKit / iCloud** if you turn on sync between your devices
- **SaneApps distribution service** for privacy-preserving aggregate app counts
- **Cloudflare Web Analytics** on public website pages for cookie-free aggregate traffic stats, such as page views and referrers

These website services apply to `saneclip.com` pages, not to your clipboard history inside the app.

## iCloud Sync And Encryption

SaneClip does not run a clipboard sync server. If you enable sync, SaneClip uses Apple's CloudKit in your own iCloud account to move clipboard items between your devices.

When History Encryption is enabled, clipboard content is encrypted with AES-GCM before it is uploaded to CloudKit and decrypted on-device when SaneClip reads it back. In that mode, SaneApps cannot read your synced clipboard content, and Apple receives encrypted payloads rather than plaintext clipboard content.

Without History Encryption, iCloud still uses Apple's transport and at-rest protections, but SaneClip does not represent that as app-level end-to-end encryption. The stronger "not readable by SaneApps or Apple" claim applies to History Encryption.

## Password Protection

SaneClip includes optional protection for sensitive clipboard data:

- Touch ID or password lock for history access
- Sensitive-data detection to avoid saving likely passwords or payment details
- Cleanup rules for copied content you do not want to keep

## Your Control

You can:

- Clear your history at any time
- Turn off optional sync
- Remove webhooks
- Delete local app data

## Contact

Questions about privacy?

- GitHub: [github.com/sane-apps/SaneClip](https://github.com/sane-apps/SaneClip)
- Email: [privacy@saneapps.com](mailto:privacy@saneapps.com)
