# Privacy Policy

> [README](README.md) · [ARCHITECTURE](ARCHITECTURE.md) · [DEVELOPMENT](DEVELOPMENT.md) · [PRIVACY](PRIVACY.md) · [SECURITY](SECURITY.md)

**Effective Date:** March 26, 2026
**Last Updated:** April 25, 2026

SaneClip is built to keep your clipboard history on your device. This page explains what stays local, when the app uses the network, and why.

## The Short Version

- Your clipboard history stays on your Mac by default
- Optional iCloud sync works only between your own devices if you turn it on
- Optional webhooks send data only if you set them up
- The app may send privacy-preserving aggregate counts, such as whether it opened in Free or Pro, whether an upgrade button was clicked, whether a license was activated, app version, build, and update status
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

Those app counts do not include your clipboard contents.

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
- **CloudKit / iCloud** if you turn on sync
- **SaneApps distribution service** for privacy-preserving aggregate app counts
- **Cloudflare Web Analytics** on public website pages for cookie-free aggregate traffic stats, such as page views and referrers

These website services apply to `saneclip.com` pages, not to your clipboard history inside the app.

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
