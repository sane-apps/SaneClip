# Session Handoff — SaneClip

Active handoff only. Older capture/App Store/pricing notes were compacted on
2026-05-21 to keep startup context small. Durable history remains in git,
`CHANGELOG.md`, `ARCHITECTURE.md`, Serena memory, and the knowledge graph.

## Current State

- Current public/direct version: `2.3.5`.
- Current repo train: post-`2.3.4` Capture Text, clipboard history shortcut,
  snippets paste discoverability, and App Store screenshot repair work.
- App Store macOS `2.3.4` was resubmitted after valid macOS screenshots were
  generated. The next combined macOS+iOS submission requires a version bump
  because the iOS lane was already final-state `READY_FOR_SALE` for `2.3.4`.
- GitHub issue posture from the last active pass:
  - `#9` edit/save still needs real right-click/context-menu runtime proof.
  - `#10`, `#11`, and `#12` map to local shortcut/Capture Text/snippet
    discoverability fixes but should not be closed or publicly replied to
    without exact draft approval.
- Customer UI contract is currently red in global validation because the receipt
  is stale and uses reused docs screenshots. Clear it by rerunning the Mini
  customer UI sweep, not by editing the receipt.

## Active Blockers

- Refresh release/customer UI proof:
  `./scripts/SaneMaster.rb customer_ui_sweep --json`
  followed by `./scripts/SaneMaster.rb customer_ui_contract --no-exit`.
- Recheck App Store lane state before any new submission; do not reuse old
  `2.3.4` assumptions for a combined macOS+iOS release.
- README version mention warning: make sure public docs mention `2.3.5` before
  the next doc validation run.

## Verification Receipts

- 2026-05-12 Mini verify passed 152 tests after the Capture Text stream-path and
  shortcut reliability fixes.
- 2026-05-12 Mini `customer_ui_sweep --no-exit` and
  `customer_ui_contract --no-exit` passed with 12 release-required actions, but
  that receipt is now stale and must be refreshed.
- 2026-05-17 App Store screenshot repair used
  `appstore_submit.rb --test-screenshots`; all six macOS screenshots resized to
  Apple's `2880x1800` desktop target.

## Next

1. Run fresh Mini customer UI proof for `2.3.5`.
2. Update README/current docs if version copy still omits `2.3.5`.
3. Only after green proof, draft any GitHub issue replies for user approval.
