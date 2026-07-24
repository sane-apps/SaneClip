# Session Handoff - SaneClip

## Current State (2026-07-24)

SaneClip `2.3.22` is the active direct-download and App Store candidate. It adds
optional on-device Rewrite, Summarize, and Extract Key Points previews for text
clips on macOS 26+ Apple Intelligence-capable Macs, plus a cross-channel
single-instance guard.

- AI input is limited to 2,000 UTF-8 bytes before model availability or
  generation work, so token-dense Unicode cannot bypass the bound.
- Each action uses a fresh Foundation Models session with no tools. Static
  policy stays in `Instructions`; only the selected clip is the `Prompt`.
- Generated text remains transient until Copy. Copy changes the pasteboard but
  not clipboard history; Cancel changes nothing. The removed Replace path must
  not return without a new persistence and recovery design.
- Direct, Debug, App Store, and Setapp bundle IDs are one logical app family.
  The oldest launch survives; PID is only the deterministic tie/fallback.
- Public copy explicitly states the macOS 26, eligible Mac, Apple Intelligence
  enablement, and model-readiness requirements.

## Evidence

- Candidate verification passed **241 tests in 13 suites** on the Mini; workflow
  receipt `bfbe7c59f65200970ee5863b648db584`.
- The 13-action customer UI workflow/contract passed against the current
  privacy-safe AI traversal schema. The live proof binds the current source,
  installed executable, and clean synthetic screenshot without storing prompt,
  result, or pasteboard text; workflow receipt
  `27d24b0d9938194c948a003bd1f51bbf`.
- Fresh Developer ID Release build, canonical install, and launch passed;
  receipt `dab21a9ee1d2813ca1e3056371a4d415`.
- Fresh visual smoke passed with clean workspace evidence; receipt
  `cef4f878e6bac901a595a467fbca7923`.
- Direct release preflight passed with expected pre-publish warnings; receipt
  `b945864086075c03b03fbbc52a5f463a`.
- The shared SaneProcess dedupe flow now unregisters recoverable SaneClip copies
  already in Trash before re-registering `/Applications/SaneClip.app`; its
  focused test suite passed 5/5.
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
  --project "$(pwd)" --full --version 2.3.22 \
  --notes "Adds optional private on-device text previews on eligible macOS 26 Macs and prevents parallel SaneClip runtime channels." \
  --deploy
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
