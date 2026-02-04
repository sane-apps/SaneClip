# Session Handoff - 2026-02-03

## ✅ COMPLETED: SaneClip 1.4 Release (Feb 3)

**Status:** Release complete and fully deployed

### What Was Done
1. ✅ **Xcode MCP Migration** — All config files already updated
2. ✅ **Version Bump** — 1.3 (build 5) → 1.4 (build 6)
3. ✅ **Build & Test** — All 47 tests passing (22 new security tests)
4. ✅ **Notarization** — DMG notarized and stapled by Apple
5. ✅ **R2 Upload** — SaneClip-1.4.dmg uploaded to production bucket
6. ✅ **Workers Fix** — Fixed dist.saneclip.com routing (was missing --remote flag)
7. ✅ **Website Deploy** — docs/ deployed to Cloudflare Pages
8. ✅ **Appcast Updated** — appcast.xml includes 1.4 with Sparkle signature
9. ✅ **CHANGELOG** — Full 1.4 release notes documented
10. ✅ **Git Push** — All commits pushed to main

### Release Details

**Version:** 1.4 (build 6)
**Release Date:** 2026-02-03
**File:** SaneClip-1.4.dmg
**Size:** 2,850,157 bytes (2.7 MB)
**SHA256:** `c5d0986635012087f57151a412958e7fb5a0353058cc7f39ff7c64c8c901c687`
**Sparkle Signature:** `opEhZGHtZgwTiHXRt63XW/QiO/Ft8gorj0djRIez7v++32gT6rG0hAQzgHXfI8ziJQSv2opQjcz9wv6Uay+TAg==`

### Live URLs (All Verified Working)
- ✅ Download: https://dist.saneclip.com/updates/SaneClip-1.4.dmg (HTTP 200)
- ✅ Appcast: https://saneclip.com/appcast.xml (includes 1.4)
- ✅ Website: https://saneclip.com (Cloudflare Pages)

### Security Features in 1.4
- 🔐 **Keychain Integration** — All secrets stored in macOS Keychain
- 🔒 **AES-256-GCM Encryption** — History encrypted at rest (default on)
- ✅ **URL Scheme Confirmation** — Destructive commands require user approval
- 🌐 **HTTPS Enforcement** — Webhooks must use HTTPS (localhost exempt)
- 🔄 **Seamless Migration** — Plaintext → encrypted auto-migration

### Critical Fix During Release

**Issue:** dist.saneclip.com returned 404 for uploaded DMG
**Root Cause:** Wrangler uploaded to local dev bucket without `--remote` flag
**Fix:** Re-uploaded with `--remote` flag to production R2 bucket
**Lesson:** Always use `--remote` for production R2 uploads

### Testing Completed
- ✅ Build verification (Xcode release build)
- ✅ Test suite (47/47 passing)
- ✅ Notarization acceptance (Apple approved)
- ✅ DMG download (HTTP 200, correct size/ETag)
- ✅ Appcast accessibility (Sparkle can fetch updates)

### Next Actions (User)
1. **Test Sparkle auto-update** — Install 1.3, check for updates to 1.4
2. **Manual verification** — Test security features (URL scheme confirmations, encryption migration)
3. **Marketing** — Announce security hardening release
4. **App Store** — Take screenshots from App Store build (reminder from Jan 27)

### Git Commits (This Session)
- `5b82466` - docs: complete Xcode 26.3 MCP migration
- `19802a9` - release: SaneClip 1.4 - Security Hardening

---

## Previous Session Notes

### Xcode 26.3 MCP Migration (Feb 3)

Apple released **Xcode 26.3 RC** with `xcrun mcpbridge` — official MCP replacing community XcodeBuildMCP.

**Status:** ✅ Complete — All project files already referenced the new `xcode` MCP server.

**xcode quick ref:** 20 tools via `xcrun mcpbridge`. Needs Xcode running + project open. All tools need `tabIdentifier` (get from `XcodeListWindows`). Key tools: `BuildProject`, `RunAllTests`, `RunSomeTests`, `RenderPreview`, `DocumentationSearch`, `GetBuildLog`.

---

### Release Script Audit Fix (Jan 30)

#### CRITICAL: Sparkle Signing Was Completely Missing
Cross-project audit found SaneProcess `release.sh` had **NO Sparkle signing section at all** - only generated SHA256 hash. This meant SaneClip DMGs could not be verified by Sparkle, breaking auto-updates.

#### Round 1 Fixes
Added complete Sparkle signing section to SaneProcess `scripts/release.sh`:
- Keychain fetch for EdDSA Private Key
- `sign_update.swift` call to generate signature
- Full heredoc appcast template with all attributes
- `<description>` CDATA block
- `.meta` file output (VERSION, BUILD, SHA256, SIZE, SIGNATURE)
- R2 upload instructions

#### Round 2 Fixes (Feature Parity)
- Added SUPublicEDKey/SUFeedURL verification (reads built Info.plist before shipping)

#### Live Testing (Jan 30)
- SaneClip-1.3.dmg (2.5MB) signed with Sparkle EdDSA key → 88-char base64 signature PASS
- FILE_SIZE correctly scoped outside signature check (line 408)
- Full pipeline simulation verified clean appcast XML output

#### The Rule
- `sparkle:version` = BUILD_NUMBER (numeric CFBundleVersion)
- `sparkle:shortVersionString` = VERSION (semantic version)
- URL: `https://dist.saneclip.com/updates/SaneClip-{version}.dmg`
- `sign_update.swift` already existed in `scripts/` - was just never called

---

# Previous Session Handoff - 2026-01-27 11:50 PM

> **Navigation**
> | Bugs | Features | How to Work | Releases | Testimonials |
> |------|----------|-------------|----------|--------------|
> | [BUG_TRACKING.md](BUG_TRACKING.md) | [marketing/feature-requests.md](marketing/feature-requests.md) | [DEVELOPMENT.md](DEVELOPMENT.md) | [CHANGELOG.md](CHANGELOG.md) | [marketing/testimonials.md](marketing/testimonials.md) |

---

## Completed This Session (Jan 27)

### Security Hardening (Audit: 7/10 → targeting 9/10)

Implemented 6-part security hardening plan from audit findings:

1. **KeychainHelper** (`Core/Security/KeychainHelper.swift`) — New Sendable struct with static Keychain CRUD. Service: `com.saneclip.app`. Account constants for webhook-secret and history-encryption-key.

2. **URL Scheme Confirmation Dialogs** (`Core/URLScheme/URLSchemeHandler.swift`, `SaneClipApp.swift`) — Destructive commands (copy, paste, snippet, clear) now show confirmation alerts. Added `URLSchemeCommand` enum with `parseCommand()` for testability and `requiresConfirmation` property. **Also wired `application(_:open:)` in app delegate** — URL scheme was registered in Info.plist but never connected (URLs were silently dropped).

3. **Webhook HTTPS Enforcement** (`Core/Webhooks/WebhookService.swift`) — `isSecureEndpoint()` requires HTTPS (localhost exempt). Belt-and-suspenders check at both `updateConfig()` and `sendWebhook()`. Webhook secret auto-migrates from plaintext JSON to Keychain on first load. `updateConfig()` now throws on insecure endpoints.

4. **History Encryption-at-Rest** (`Core/Security/HistoryEncryption.swift`, `Core/ClipboardManager.swift`) — AES-256-GCM via CryptoKit. Key auto-generated and stored in Keychain. `saveHistory()` encrypts, `loadHistory()` auto-detects plaintext vs encrypted for seamless migration. `exportHistoryFromDisk()` also handles encrypted files.

5. **Encrypt History Setting** (`Core/SettingsModel.swift`, `UI/Settings/SettingsView.swift`) — `encryptHistory` property (default `true`). Toggle in Security section with biometric auth required to disable. Included in settings export/import.

6. **Entitlements** (`SaneClip/SaneClipAppStore.entitlements`) — Added `keychain-access-groups` for App Store sandbox builds.

### Tests
- **22 new security tests** in `Tests/SecurityTests.swift` (URL scheme parsing, confirmation requirements, HTTPS enforcement, Keychain round-trip, encryption round-trip)
- Split into separate file to stay under SwiftLint's 350-line type body limit

---

## Build Status (Jan 27)

**Debug build: PASSING**
**Tests: 47/47 PASSING** (25 existing + 22 new security tests)

---

## Version Info (Jan 27)
- Version at time: **1.3 (build 5)**
- **Now released as 1.4 (build 6)** on Feb 3

---

## User Action Required (from previous sessions)
- [x] ~~Upload `~/Desktop/SaneClip-1.3.dmg` to Lemon Squeezy product page~~ (superseded by 1.4)
- [ ] Scrape Facebook/Twitter debuggers to bust cached OG previews for saneapps.com
- [ ] Take App Store screenshots from App Store build

---

## Gotchas

| Issue | Detail |
|-------|--------|
| R2 bucket name | `sanebar-downloads` (shared for all SaneApps), NOT `saneclip-dist` |
| R2 routing | Worker `sane-dist` routes `dist.saneclip.com` → `sanebar-downloads` bucket |
| R2 upload flag | **ALWAYS use `--remote` flag** for production uploads (learned Feb 3) |
| Sparkle signing | Use custom `scripts/sign_update.swift` — key is under `EdDSA Private Key` not `ed25519` |
| SwiftLint archive | `scripts/` dir must be excluded in `.swiftlint.yml` |
| Upload to R2 | `npx wrangler r2 object put sanebar-downloads/SaneClip-X.Y.dmg --file ... --remote` |
| SourceKit false positives | SourceKit shows "Cannot find X in scope" for cross-file refs — these are IDE indexing artifacts, compiler resolves fine |
| `encryptHistory` default | `true` for new installs — existing users get encryption on next launch |
| Keychain in sandbox | App Store builds need `keychain-access-groups` entitlement (added) |
