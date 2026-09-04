# Session Handoff - SaneClip

## Current State (2026-09-03 finish-line verify)

Verified live (do not claim otherwise):

| Lane | Truth |
|---|---|
| Sparkle appcast `https://saneclip.com/appcast.xml` | latest **2.3.23** (build 2323) |
| Direct ZIP `https://dist.saneclip.com/updates/SaneClip-2.3.23.zip` | HTTP 200, ~5.3 MB |
| Direct ZIP `.../SaneClip-2.3.24.zip` | **HTTP 404 — not published** |
| Website download JSON / CTA | still points at **2.3.23** |
| Lemon hosted file (SaneMaster status) | **2.3.22** while expected **2.3.23** (variant 1228215) — needs explicit hosted-file replace approval |
| `main` source (`ed3f1f7`) | marketing version bumped to **2.3.24** in `project.yml` + site metadata, but release/deploy never finished |

Finish-line verdict: **2.3.23 is live on Sparkle/R2/site; 2.3.24 is mid-prep only; Lemon is one version behind 2.3.23.**

Next actions (need owner approval before mutate):
1. Replace Lemon hosted file 2.3.22 → 2.3.23 (parity with live ZIP/appcast).
2. Either complete `release.sh --version 2.3.24 --deploy` from Mini after verify/preflight, or roll marketing version back to 2.3.23 until ready.
3. Air checkout is behind `origin/main` by 5 commits and has unrelated dirty local files — pull/rebase only after those dirties are sorted.

## Current State (2026-07-30)

SaneClip `2.3.23` is the current source and appcast lane. The Lemon Squeezy
hosted file still reports `2.3.22`; do not claim hosted-file parity or mutate
that dashboard without explicit approval. The current app adds
optional on-device Rewrite, Summarize, and Extract Key Points previews for text
clips on macOS 26+ Apple Intelligence-capable Macs, plus a cross-channel
single-instance guard.

### 2026-07-30 verification boundary

- An old editor-shortcut research lock was independently certified
  `RESOLVED`: fix commit `18815ce3c690f3c9163ca709eaa4e42bb8c70300`
  is tested and shipped through 2.3.23. Gate receipt:
  `eae26beb38ddb14a`.
- Canonical Mini verification passed twice: 244 tests in 13 suites with
  receipts `e9e5b738bec9b5f527640d9a59556cb7` and
  `fc1eda7fb2e8033aace8d9d5f39285a9`.
- Both supported environment attempts failed to create the requested Glenn
  render files. Stop retrying until the Xcode test-host render path is fixed.
- Customer UI contract receipt `4c6b26ce0aef93fdd9d6b612b48a5d66`
  is red: the receipt/source binding is stale, render and runtime artifacts
  are missing, and `on-device-ai-text-actions` has no fresh result.
- No live AI mutation, release preflight, App Store preflight, upload, or
  release ran. The source/tests are green; release proof is not.

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
  --project "$(pwd)" --full --version 2.3.23 \
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

## Current State (2026-09-03 release attempt — preflight RED, no deploy)

- Live re-verified: appcast latest **2.3.23**, `SaneClip-2.3.23.zip` HTTP 200 (~5.3 MB), `SaneClip-2.3.24.zip` HTTP 404, site `/download` CTA points at 2.3.23. Unchanged from finish-line verify.
- `release_preflight` RED (no `--deploy` run): blocked by research lock `saneclip-editor-shortcuts` (created 2026-06-06, 4 matched issues all CLOSED; no `.claude/research.md` exists, no fresh research run). Receipt `fcf1b701dfde6221711b9fd83f162f19`. Clearing needs the research run + research.md update, or a gate-certifier override — neither done this run per stop-and-report orders.
- Per red-gate fallback: rolled `project.yml` back to **MARKETING_VERSION 2.3.23 / CURRENT_PROJECT_VERSION 2323** (6 configs, 12-line diff, uncommitted, no publish). Matches exact pre-bump state (`56b0601~1`) and the live lane. `docs/` still mentions 2.3.24 in committed metadata (mid-prep residue); untouched.
- Dirty-tree note: `.saneprocess` (App Store copy), `docs/*.html` (og-image-20260827, @MrSaneApps handle, CSS/cross-sell edits) + untracked og images are cosmetic/site-side and did not factor into the gate; they do NOT block, but will ride along on the next `--deploy` site publish unless reverted first.
- Lemon: no scripted/API replace route — `hosted_file_actions` is export/tracker only ("file replacement and cleanup are still dashboard actions"). Manual step for owner: upload `SaneClip-2.3.23.zip` (from `https://dist.saneclip.com/updates/SaneClip-2.3.23.zip`) to product 779223 / variant 1228215 at `https://app.lemonsqueezy.com/products/779223`, unpublish 2.3.22 file.
- Nothing committed or pushed. No `verify` build run (moot once preflight went red).

## Current State (2026-09-03 research-gate clear + blocked 2.3.24 deploy, implementer run)

- Research lock `saneclip-editor-shortcuts` CLEARED with genuine fresh research
  (not an override): fix 18815ce `HistoryShortcutGate` verified still in tree
  (`UI/History/ClipboardHistoryView.swift` ~33-53, call sites ~302/~651) with
  regression tests (`Tests/SaneClipTests.swift` gate assertions); 2.3.24 diff
  is version-metadata/site-links only, no shortcut-handling change; fresh web
  check (2026-09-03) confirms first-responder gating is current macOS practice.
  Findings recorded in `.claude/research.md` (fresh mtime 2026-09-03).
  `research_status` green (receipt `eebdc88b9b22e690300841ddfd03bfe3`).
  Reconciliation: the 2026-08-28 certifier override (4d322859) was correct but
  TTL-7200s expired, and root `.gitignore:168` ignores `.claude/research.md`
  so the card never survives drift — gate re-armed deterministically.
  Durable fix needs owner call: un-ignore research.md or promote the card.
- `release_preflight` still RED on the next gate: customer-UI contract needs a
  fresh sweep; sweep fails on missing live AI traversal receipt
  (`outputs/customer-ui/ai-proof/runtime-traversal.json`) — same failure as the
  2026-08-28 runs. No scripted producer exists; it requires a live interactive
  traversal (AI Rewrite menu/result/Copy/pasteboard check + Summarize cancel +
  screenshot on the 2.3.24 installed app). Attempted via peekaboo/AX/URL scheme
  but history UI would not surface headless (no menubar item, hotkey no-op,
  `saneclip://history` silent) on the owner-active Mini — stopped rather than
  drive blind GUI on a live machine. No deploy ran. No push.
- Fallback per red-gate orders (local commits, NOT pushed):
  `1c69a7d` (README live-lane heading back to 2.3.23),
  `433b550` (docs/index.html downloadUrl/softwareVersion + docs/download.html
  button href back to 2.3.23; surgical hunks only, cosmetic hunks untouched).
  Sweep-script 2.3.24 pin kept on its merits (must match project.yml).
  project.yml restored to committed 2.3.24 (prior run had rolled it to 2.3.23;
  sweep contract requires 2.3.24).
- Live lane verified clean: saneclip.com/ and /download serve 2.3.23 links,
  2.3.23 ZIP 200, 2.3.24 ZIP 404. No published page links a 404.
- Mini state notes: quit stale SaneVideo window for sweep precheck; SaneClip
  relaunched fresh (single instance, 2.3.24). A "ruby would like to access
  your Photo Library" TCC prompt is on screen (predates this run, from sweep
  visual_smoke) — left unclicked. Lemon untouched per scope.
- Next owner action to ship 2.3.24: run the live AI traversal on the Mini
  (open history, AI Rewrite on synthetic text to result, Copy, verify
  pasteboard + unchanged history, Summarize Cancel, screenshot, write
  privacy-safe receipt per `verify_ai_runtime_traversal!`), then
  `customer_ui_sweep` -> `release_preflight` -> `release.sh --version 2.3.24
  --deploy`. Then re-bump the four live-lane doc lines to 2.3.24 (revert
  1c69a7d/433b550 version hunks) as part of the release.

## Current State (2026-09-03 live AI traversal attempt - BLOCKED at step 1, no deploy)

- Research gate GREEN (re-verified this run): card .claude/research.md present (fresh 2026-09-03, saneclip-editor-shortcuts RESOLVED), research_status clear (receipt c45ad1eb). No re-record needed.
- Live lane unchanged: appcast latest 2.3.23, 2.3.23 ZIP 200, 2.3.24 ZIP 404, site CTA 2.3.23. project.yml 2.3.24/2324; docs live-lane lines at 2.3.23 (local commits 1c69a7d/433b550, NOT pushed).
- BLOCKER A (environmental, 3 pids sampled): installed 2.3.24 wedges at launch on the Mini. Main thread stuck in applicationDidFinishLaunching -> LicenseService.checkCachedLicense -> KeychainService.string -> SecItemCopyMatching -> mach_msg SecurityServer (stacks in outputs/live-logs/ai-traversal-findings-20260903.txt). No setupApp runs: no capture, no hotkeys, no status UI, AppleEvents time out. Cause: keychain unreachable from the 4.6h-idle console with nobody to approve. In-tree bypass SANEAPPS_FORCE_FREE_MODE=1 IS honored by the 2.3.24 binary and restores the app (capture verified with synthetic probes; status menu renders). SANEAPPS_FORCE_PRO_MODE=1 is NOT honored by the installed binary (same hang sampled; pro-mode string absent from binary) - predates that SaneUI commit.
- BLOCKER B (product, needs code investigation): with the app healthy (force-free pid 93496, capture alive, Foundation Models probed AVAILABLE), the history NSPopover NEVER paints. Window object exists (346x526 layer 25) but backing store stays empty (~2KB), zero AX windows, nothing in captures - via hotkey, status-item click, status-menu Show History, at-button AND at-cursor (pref tried then reverted to 0). AppKit menus render fine, so the AI sheet hosted in the popover is unreachable in the GUI. No sweep / preflight / deploy / push ran (red gate stops the line). Lemon untouched.
- Mini state left: ONE SaneClip running (pid 93496, force-free env); openHistoryAtCursor restored to 0; Simulator/Brave/TextEdit re-shown after mid-run hide; history.json gained a few clearly-synthetic probe items (within free-tier trim); nothing committed or pushed. Log receipt: outputs/live-logs/ai-traversal-20260903.log.
- Exact next steps for owner: (1) at the Mini console, approve/unlock any SaneClip keychain prompt and relaunch normally; (2) check whether the history popover paints on a normal launch - if not, file a 2.3.24-on-Tahoe popover bug (async keychain read + popover ordering) and fix before ship; (3) re-run the traversal to produce outputs/customer-ui/ai-proof/runtime-traversal.json, then sweep -> preflight -> release.sh 2.3.24 --deploy. Mode note: a traversal under SANEAPPS_FORCE_FREE_MODE must be disclosed; the AI flow itself has no tier gates (verified in ClipboardItemRow, sheet, and Copy path).

## 2026-09-03 late — launch-hang fix verified live, release chain BLOCKED on Mini AI model

Root causes found:
1. Launch hang: SaneClip pins SaneUI at 7f87b04, which predates the silent-keychain-reads fix 8568997. The pinned KeychainService does bare SecItemCopyMatching with no non-interactive policy, called synchronously on the main thread from checkCachedLicense (SaneClipApp.swift line 141 area). On the idle Mini console the login-keychain ACL prompt cannot be answered, so the main thread wedges in mach_msg to SecurityServer forever. Bumping the pin was rejected: 15 commits in between include product-behavior changes (hard buy screen end of trial, FORCE_PRO in Release, donate hooks, type churn).
2. Empty-popover verdict was an idle-console artifact, not an app bug. Window listing on the sleeping Mini shows EVERY window (Finder, Brave, Xcode, Dock) with the same 2368-byte stub backing store. Live AX inspection of the fixed build shows the popover opens at the correct size with 50+ real history rows plus footer actions. No rendering fix needed.
3. Dead open path found and fixed: saneclip history URL posts SaneClipShowHistory but nothing observed it. Wired to the auth-gated popover entry.
4. AI traversal RED (environmental): this Mini has no on-device language-model assets (empty GenerativeModels asset dir). Menu opens, Rewrite starts, sheet reaches loading, but inference never returns a result (100s+ in loading) and Summarize ends in Could not Generate Result. The app handles it with the designed error UI. No result means runtime-traversal.json cannot be completed honestly.

Fix (Mini working tree, not pushed):
- Core/Security/NonBlockingKeychainService.swift (new): Sendable wrapper over the SaneUI keychain protocol; every op runs on a background queue with a 2s bound; stalled reads return nil so launch falls back to free or trial mode; stalled writes throw; inner errors propagate. Same backing store SaneUI uses by default.
- SaneClipApp.swift: all three LicenseService constructions inject the wrapper; setupApp observes SaneClipShowHistory via handleShowHistoryNotification to showPopover on main.
- Tests/NonBlockingKeychainServiceTests.swift (new, 4 tests) and HistoryWindowTests urlSchemeHistoryEntryOpensPopover: all pass.
- SaneClip.xcodeproj regenerated with xcodegen.

Verification evidence:
- Debug verify: 250 tests, only reds are the two pre-existing marketing-copy tests caused by the intentional docs rollback to 2.3.23 (index/download/README expect 2.3.24; release re-bump resolves). Touched areas green, latest receipt dir outputs/verify/20260904T003623Z.
- Release 2.3.24 build 2324 signed and notarized, SHA c561ca67fd7483c873f071a015070e885fa5232fb6623650cb4ae882d4c71730, installed to /Applications (broken build moved to /tmp/SaneClip-broken-2.3.24.app). Normal launch completes: main thread healthy in the event loop, CloudKit sync running, no keychain stall.
- Installed build contains the license fix. The URL-observer fix is source-only and rides the next Release build.
- One synthetic probe clip was added to history during testing.

BLOCKED next step (needs owner on the Mini console): turn on Apple Intelligence in System Settings and let the on-device model download finish, then say the word and the chain resumes: live AI traversal receipt, customer_ui_sweep, release_preflight, release.sh version 2.3.24 deploy. Lemon Squeezy dashboard untouched per scope.
