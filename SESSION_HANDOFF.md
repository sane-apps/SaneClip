# Session Handoff - 2026-02-03

## ACTION REQUIRED: Xcode 26.3 MCP Migration (Feb 3)

Apple released **Xcode 26.3 RC** with `xcrun mcpbridge` — official MCP replacing community XcodeBuildMCP.

**Already done globally:** `~/.claude.json` has `xcode` server, `~/.claude/settings.json` has `mcp__xcode__*` permission. XcodeBuildMCP removed from global config.

**TODO in this project:**
1. **`CLAUDE.md`** — Replace XcodeBuildMCP session-set-defaults section (lines ~44-45)
2. **`DEVELOPMENT.md`** — Update XcodeBuildMCP reference (line ~377)
3. **`.mcp.json`** — Remove XcodeBuildMCP entry (Cursor config)
4. **`.saneprocess`** — Check/update if references XcodeBuildMCP

**xcode quick ref:** 20 tools via `xcrun mcpbridge`. Needs Xcode running + project open. All tools need `tabIdentifier` (get from `XcodeListWindows`). Key tools: `BuildProject`, `RunAllTests`, `RunSomeTests`, `RenderPreview`, `DocumentationSearch`, `GetBuildLog`.

---

## Release Script Audit Fix (Jan 30)

### CRITICAL: Sparkle Signing Was Completely Missing
Cross-project audit found SaneProcess `release.sh` had **NO Sparkle signing section at all** - only generated SHA256 hash. This meant SaneClip DMGs could not be verified by Sparkle, breaking auto-updates.

### Round 1 Fixes
Added complete Sparkle signing section to SaneProcess `scripts/release.sh`:
- Keychain fetch for EdDSA Private Key
- `sign_update.swift` call to generate signature
- Full heredoc appcast template with all attributes
- `<description>` CDATA block
- `.meta` file output (VERSION, BUILD, SHA256, SIZE, SIGNATURE)
- R2 upload instructions

### Round 2 Fixes (Feature Parity)
- Added SUPublicEDKey/SUFeedURL verification (reads built Info.plist before shipping)

### Live Testing (Jan 30)
- SaneClip-1.3.dmg (2.5MB) signed with Sparkle EdDSA key → 88-char base64 signature PASS
- FILE_SIZE correctly scoped outside signature check (line 408)
- Full pipeline simulation verified clean appcast XML output

### The Rule
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

## Completed This Session

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

## Build Status

**Debug build: PASSING**
**Tests: 47/47 PASSING** (25 existing + 22 new security tests)

---

## Version Info
- Current version: **1.3 (build 5)**
- No version bump needed — security hardening is internal, no user-facing version change yet

---

## Changes Not Yet Committed

All security hardening changes are unstaged. Files changed/added:
- `Core/Security/KeychainHelper.swift` (NEW)
- `Core/Security/HistoryEncryption.swift` (NEW)
- `Tests/SecurityTests.swift` (NEW)
- `Core/Webhooks/WebhookService.swift` (MODIFIED)
- `Core/URLScheme/URLSchemeHandler.swift` (MODIFIED)
- `Core/ClipboardManager.swift` (MODIFIED)
- `Core/SettingsModel.swift` (MODIFIED)
- `UI/Settings/SettingsView.swift` (MODIFIED)
- `SaneClipApp.swift` (MODIFIED)
- `SaneClip/SaneClipAppStore.entitlements` (MODIFIED)

---

## User Action Required (from previous sessions)
- [ ] Upload `~/Desktop/SaneClip-1.3.dmg` to Lemon Squeezy product page
- [ ] Scrape Facebook/Twitter debuggers to bust cached OG previews for saneapps.com

---

## Next Session Reminders
1. **Commit security hardening** — all changes are verified (47/47 tests pass) but not committed
2. **Verify manually**: launch app, check `saneclip://copy?text=test` shows confirmation, check history.json is encrypted after restart
3. **Take App Store screenshots** from App Store build — user explicitly asked to be reminded
4. **Marketing updates** — user said "tomorrow" (from Jan 27 session)
5. App Store Connect: create app record, fill description/keywords/pricing
6. Consider bumping to v1.4 for the security release

---

## Gotchas

| Issue | Detail |
|-------|--------|
| R2 bucket name | `sanebar-downloads` (shared for all SaneApps), NOT `saneclip-dist` |
| R2 routing | Worker `sane-dist` routes `dist.saneclip.com` → `sanebar-downloads` bucket |
| Sparkle signing | Use custom `scripts/sign_update.swift` — key is under `EdDSA Private Key` not `ed25519` |
| SwiftLint archive | `scripts/` dir must be excluded in `.swiftlint.yml` |
| Upload to R2 | `npx wrangler r2 object put sanebar-downloads/SaneClip-X.Y.dmg --file ... --remote` |
| SourceKit false positives | SourceKit shows "Cannot find X in scope" for cross-file refs — these are IDE indexing artifacts, compiler resolves fine |
| `encryptHistory` default | `true` for new installs — existing users get encryption on next launch |
| Keychain in sandbox | App Store builds need `keychain-access-groups` entitlement (added) |
