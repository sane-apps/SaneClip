# Session Handoff - SaneClip

## Current State (2026-07-18)

SaneClip `2.3.21` is the active release candidate for the direct and App Store
lanes. The candidate adds valid direct-license recognition for the public
SaneApps five-app bundle without changing the App Store purchase path.

- Bundle checkout: `https://go.saneapps.com/buy/bundle` ($49.99 one-time).
- Direct license matching uses the published SaneUI revision and accepts a
  verified SaneApps bundle only when the server-validated product name includes
  `SaneClip`.
- History-lock authentication now fails closed: Touch ID, device-owner
  authentication, or no unlock. It never silently opens protected history.
- The direct app mover passes source and destination paths to AppleScript as
  arguments, preventing path-text injection into privileged shell commands.
- App Store metadata now accurately describes authentication reliability and
  continues to state that App Store builds use no external checkout or license
  keys.
- The shared release pipeline updates the Homebrew cask macOS requirement from
  `.saneprocess` (SaneClip 14.0 maps to Sonoma), alongside version and SHA.

## Evidence

- Candidate verification: `./scripts/SaneMaster.rb verify --timeout 900
  --no-grant-permissions` passed **228 tests in 13 suites** on the Mini on
  2026-07-18.
- Shared SaneProcess release guardrails passed **231/231** after the Homebrew
  macOS synchronization fix.
- A generated `.sane/customer_ui_action_receipt.json` is runtime evidence only;
  do not commit it. Regenerate it after any customer-facing source change.
- Existing lint warnings remain non-blocking technical debt: `SaneClipApp.swift`
  and `SyncCoordinator.swift` exceed the preferred file length, and one
  `ClipboardManager` function has six parameters.

## Release Procedure

Run the following only from the Mini candidate after the required audit and
review checkpoints are complete. Do not upload R2 objects, edit appcasts, or
edit the Homebrew cask manually.

```bash
./scripts/SaneMaster.rb verify --timeout 900 --no-grant-permissions
./scripts/SaneMaster.rb customer_ui_sweep
./scripts/SaneMaster.rb release_preflight
./scripts/SaneMaster.rb appstore_preflight
bash ~/SaneApps/infra/SaneProcess/scripts/release.sh \
  --project "$(pwd)" --full --version 2.3.21 --notes "..." --deploy
```

After publish, read back the live ZIP, appcast, website download route, bundle
checkout, and Homebrew cask version, SHA, and Sonoma requirement before calling
the release complete.

## Scope Notes

- Direct distribution and App Store are distinct lanes. The App Store build
  unlocks through StoreKit and must never show direct checkout or license-key
  instructions.
- Setapp is a separate lane and is not part of this direct/App Store release.
- Durable historical release details belong in Git, `CHANGELOG.md`, and
  `ARCHITECTURE.md`; this file is intentionally only current operational state.
