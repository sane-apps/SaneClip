# Session handoff — 2026-09-08 AI traversal

- Live Mini Rewrite/Copy and Summarize/Cancel passed on signed 2.3.24 (2324), PID 47937.
- Receipt: `outputs/customer-ui/ai-proof/runtime-traversal.json` (verified against sweep guards).
- Working GUI path: `peekaboo see --window-id --no-elements` then `peekaboo click --at X,Y --global --foreground --no-auto-focus` via `mini-gui-run.sh`.
- SOP updated: Clip `DEVELOPMENT.md` and `infra/SaneProcess/scripts/mini/SCREENSHOT_TOOLS.md`.
- Do not use `see --app` for the history popover (layer 25). Do not snapshot-click NSMenu (SNAPSHOT_STALE). Do not pbcopy.

## 2026-09-07 14:27 ET — Nine-tab Settings on main; public 2.3.24 not cleared

- ChatGPT stopped after committing `b65142e` and launching the signed build. Remaining work was visual proof of that binary, push, and ship.
- Inspected all nine Settings tabs on the signed 2.3.24 build (PID 83409, live log `20260907T181617Z-20260907-83182-rsuyiy`): General, Clipboard, Snippets, Shortcuts, History, Privacy, Sync, License, About. Contrast/hierarchy hold; Snippets is compact; Privacy is complete; pink Donate hearts; no leftover build-number; License shows Licensed. Scrollable bottoms on General/History/Sync are expected, not clipping of the primary controls.
- Shots: `outputs/customer-ui/portfolio-20260907/committed-{General,Clipboard,Snippets,Shortcuts,History,Privacy,Sync,License,About}.png`
- Pushed `6feb828..b65142e` to origin/main after pre-push 252/15. Air fast-forwarded to `b65142e`. Dirty website/.saneprocess files were not included.
- `release_preflight` RED (`c4e412e2232b7d8c316a263f1b87191d`): stale customer-UI contract pointing at missing July 18 sweep artifacts, settings workflow not bound to current source, on-device AI receipt stale, upgrade-path fingerprint stale. Appcast/Homebrew still 2.3.23 vs source 2.3.24 (expected before publish). No `release.sh --deploy`, no Lemon file replace.

## 2026-09-07 10:24 ET — SaneClip fixes published to main

- SaneClip main6feb8286796b7fb607f8e787f2cbd4aeaec7f36d is pushed. Pre-push canonical Mini verify passed252 tests/15 suites, workflow9ba533ec9d90bb871c1c86c4557c26d0. Commit includes cached-paid-license and closable-gate regression, shared60176f3, settings readability/layout and published-appcast test.
- Air fast-forwarded from2c69a20 to the same main. Fourteen pending native files matched Mini exactly before sync. The divergent untested Air-only KeychainHelper prototype is retained in named stash portfolio-saneclip-air-before-main-20260907, with all prior dirty work; canonical Mini implementation is now active on Air. Pending pink website edits and upgrade-proof config were reapplied.
- Real Mini Rewrite/Copy and Summarize/Cancel passed with actual Foundation Models generation. Source-bound proof: apps/SaneClip/outputs/customer-ui/portfolio-20260907/ai-runtime-proof.json. Original50 clips/all41 sandbox files restored exactly and original clipboard restored; runtime stopped normally.
- Shared unsigned monitor/proof runner changes and Clip upgrade config remain pending publication. AI diagnostic logs and website/App Store metadata remain separate dirty work. This is a source push, not a public release; full portfolio goal and remaining release/action checks stay open.

## 2026-09-07 10:21 ET — Live on-device AI and data restoration verified

- Signed Release2.3.24/2324 workflow ebd385947c6082905bb70cbf35e8804d: actual clipboard capture, search, Rewrite generation/Copy, and Summarize generation/Cancel passed on Mini. Rewrite completed in about8 seconds. Copy exactly matched preview and did not change any saved-history file. Cancel closed the preview without changing clipboard or storage.
- Three clean target-state screenshots inspected: outputs/customer-ui/portfolio-20260907/codex-shot-2026-09-07_10-16-49.png (search), 10-18-19.png (Rewrite), 10-20-04.png (Summarize). Target controls/text are complete and readable. Browser backdrop makes these private QA assets only. ai-runtime-proof.json binds sources, workflow, results and visual scope.
- This signed build is sandboxed: actual owner storage is Library/Containers/com.saneclip.app/Data/Library/Application Support/SaneClip. Backed up41 files before live capture; the50-item cap displaced one original item during the synthetic check. After normal app Quit, archived the test history and restored original history: all41 paths/SHA256 values match backup, all50 original records restored. Original clipboard restored through Peekaboo named slot. No new grant or TCC reset.
- Runtime log was ready14:06:55.962628Z before launch14:06:56.743926Z and stopped14:20:47.095014Z with app_exited. No Clip test process/log remains.
- Peekaboo4.3.1 AX set-value rejected even an immediately fresh popover snapshot as SNAPSHOT_STALE twice. No mutation dispatched. Stopped retries; documented native foreground coordinate input plus fresh AX readback worked. Tool typing returned unconfirmed while fresh AX proved the exact query; never retried blindly.
- Full release gate remains incomplete; no public release or LS file replacement claimed.

## 2026-09-07 10:07 ET — SaneClip suite and upgrade proof green

- Mini canonical verify252 tests/15 suites PASS, workflow564c36a3df0e33d1ef330abd21e89927. New existing-file regression seeds the actual2.3.23 license cache schema in an isolated fake keychain, verifies paid state/no expired gate, then recreates LicenseService with persisted defaults and a hanging keychain; cache check returns under1s and access/email remain. No real Keychain read, customer data, or new grant.
- Fixed two prior website-check failures: Mini comparison table accidentally lost hidden despite unverified competitor claims; restored hidden (Air was already hidden). Public download test now parses published appcast version and checks candidate version is not older, instead of pointing customers at unreleased2.3.24. Site change is source-only, no new browser visual/deploy proof.
- Shared monitor_tests has explicit --unsigned, propagated by release.upgrade_path_test.unsigned_tests; signed default unchanged. Uses same six signing overrides as unit-only verify.23 CI-helper and14 upgrade-proof security tests pass. Four source/test files match Air/Mini with backups. No production signing/grant change.
- .saneprocess now configures exact paidCacheSurvivesUpgradeAndUnavailableKeychain() test from2.3.23 with unsigned_tests true. Final actual upgrade_path_proof PASS workflowf8e06a5e74d10a2efce69088b1a118b0; final preflight04cc313980251c7d59d1560b2d7ebf63 ACCEPTS fresh behavioral upgrade proof. Earlier proof889e400 became stale after editing the shared runner regression test; regenerated only after source stabilized.
- Release still NOT CLEARED: missing/stale full clipboard/settings/AI/iOS customer-workflow artifacts. Existing screenshot/settings proof remains scoped. No release token, app upload, LS deletion or public version change. Native/settings/pin changes and this pass remain uncommitted pending coherent native review/main integration; user permits direct main.
- Evidence apps/SaneClip/outputs/portfolio-release-20260907; shared outputs/portfolio-review-20260906/unsigned-{monitor,upgrade}-tests.log. Air originals in air-before and air-before-unsigned; no broad reset/revert. Memory write timeouts remain parked; facts are in this handoff. Next: real customer-workflow completion and truthful per-action receipts, then release/LS replacement. Full portfolio goal remains active.

## 2026-09-06 19:08 ET active portfolio review

## 2026-09-06 20:38 ET Clip settings review and Video rebuild

- Clip settings evidence is now saved as clip-settings-visual/settings-visual-verification.json under this portfolio output directory on both hosts. Eighteen inspected image entries include complete Shortcuts/Sync scroll coverage, Storage, paid License, About with both pink Donate hearts, General sections and Snippet draft/empty-search states. Scope remains settings visual review and the actual recorded safe actions, not all app actions or release clearance.
- Actual Settings close button removed all windows while Clip remained running. Separate normal Quit ended PID47588 and its original runtime capture at2026-09-07T00:35:48.316900Z, stop_reason app_exited. No Clip test surface remains active.
- SettingsColorTests stale green-text assertion updated to white permission text; excluded-app colored status icon policy retained. Mini canonical focused verify passed3/3, workflowedcb0a77f963be796d42f3f01073d69c. These are source-policy assertions, not behavioral visual proof. Continuous test capture ready00:35:48.846267Z survived through explicit stop00:36:30.256120Z. Existing fixture runner now rejects unhealthy final log state. Source/test hashes match Air and Mini; diff --check passes.
- Video shared60176f3 rebuild is in progress via canonical GUI launch. It detected the newer Package.resolved and correctly rejected the old binary. Log video-settings-layout-patches/adaptive-shared-launch.log, status adjacent. New runtime and current Privacy & AI inspection pending; prior verified screenshots remain historical.
- No public app release, LS upload/removal, new OS grant, TCC reset, or credential change in this phase. The portfolio goal remains incomplete.

## 2026-09-06 20:23 ET active verification

- SaneClip signed Release 2.3.24/2324 now runs shared SaneUI 60176f3, PID 47588, workflow 465a6551b519a8b616ae64178e180b63. Continuous log was ready 23:58:42.258539Z before launch 23:58:42.640216Z: apps/SaneClip/outputs/runtime-logs/20260906T235842Z-20260906-47092-3mv5qc/live.log; bounded deadline 00:58:42Z. This supersedes earlier pending-build entries.
- Current native proof under infra/SaneProcess/outputs/portfolio-review-20260906/clip-settings-visual/: 19-45-51 full Per-app paste mode after shared adaptive layout; 20-03-19 real search p gives No Results and bottom-aligned 0 of 3 snippets; clear button restores list. 20-10-23 filled draft has enabled Save; 20-12-08 bottom scroll exposes complete live Preview. Actual Cancel removed sheet and preserved three saved snippets. Save was not clicked. 20-15-13 confirms list bottom reachable; 20-17-12 confirms current Shortcuts top. All named images inspected. Snippet list uses normal scrolling with sticky category header; upper offscreen row is not a full-row screenshot. Further tab checks are active.
- SaneClip SnippetsSettingsView now has white Search label, wrapped instructions, full-height empty results, filtered count, shared editor buttons/background and 520pt minimum. General Granted status is white. Scoped source/pins synchronized with backups; unrelated owner changes preserved. No public Clip release.
- Peekaboo 4.3.1 installed on Mini and Air from official openclaw/tap. Mini retains prior signing team and observed grants; Air old unmanaged 3.4.0 binary retained in portfolio output before install. Air GUI/permissions were not exercised. Dependency baseline now preserves qualified tap names; Mini 31 tests pass, both host checks PASS. No TCC resets or permission requests. Manual Mini helper PID 51635 stopped; auto helper has bounded idle exit.
- SaneCite exact prior Worker/parser pair remains the last verified live state (19:27 entry); newer release remains unshipped. Paired recovery tool/workflow/tests are still unpublished candidate changes. Video is source-pinned 60176f3 but has not rebuilt since prior verified 5931685 run.
- Portfolio goal remains active. Three delegated agents stopped on account usage limits; continue root work without retrying delegation to bypass limits. All-app, release, full action coverage and complete Air/Mini parity remain unproven.

## 2026-09-06 19:42 ET active shared layout correction

- Shared SaneUI60176f30007e0f931195785aa769e4ef5172f7ee is published and synchronized to Air. CompactRow uses native ViewThatFits: full label beside controls when space permits, label above controls when crowded. CompactToggle labels wrap. Native400pt-vs700pt layout regression passes fixed source and fails old source; complete152tests/29suites pass. Two unchanged onboarding-copy/donation assertions were stale and updated; the former source assertion banning vertical wrapping was superseded by the native regression.
- Actual Clip760x532 General screenshot19:28:26 exposed truncated Per-app paste mode, motivating shared root repair. General sections at scroll0.43,0.65,0.85,1 were inspected; no security/history settings changed. Source status text is now white. Clip search now uses a visible white Search label because native placeholder ignored explicit white prompt. Snippet Add sheet was opened, scrolled to bottom and Cancel clicked; zero sheets afterward, no saved snippet changes. Editor shared style,520pt minimum and scroll indicators prepared for verification.
- Clip old PID24822/log3c0df2a3062011b78d2e3f35b61c488d ended normally23:40:45.432Z. New signed Release launch is building via canonical wrapper, log file infra/SaneProcess/outputs/portfolio-review-20260906/clip-settings-visual/adaptive-release-launch.log. Actual new UI proof pending; no public Clip2.3.24 release.
- Clip/Video source pins now60176f3 on both machines. Video has not rebuilt after its verified5931685 settings run; no claim of current601 runtime. Air per-file before backups and hashes in clip-settings-visual/air-adaptive-sync.json; unrelated metadata preserved.

- Mini is canonical; all three delegated agents stopped on account usage limit. Root continues. Goal is active and incomplete; no blanket portfolio, release or Air/Mini parity claim.
- Video: all eight settings pages inspected at720x600, actual policy/MIT-license/Donate destinations verified, API Keys confirmation canceled, cache action preserved both valid old media fixtures exactly. Shared license5931685 was built/visually verified18:14. Video is now SOURCE-pinned to newer shared81982cd scrollbar fix; this last pin still needs Video rebuild/runtime after Clip finishes.
- Clip: shared dim text fixed; Sync repeated Status heading changed to Activity, text wraps, image copy shortened; redundant per-row snippet category chips removed, section labels13pt/search prompt white; Storage text explicitly white. Native signed Release rebuilt at23:03:40Z, workflow3c0df2a3062011b78d2e3f35b61c488d, PID24822. Continuous log ready23:03:39.668Z, receipt apps/SaneClip/outputs/runtime-logs/20260906T230339Z-20260906-24011-jef564/receipt.json; expires after3600s or app exit. This is the sole active native GUI test app.
- Clip's previous logged candidate01dab8ed had real General top, full Shortcuts top/bottom, Sync top/bottom, Snippets visible portion, complete Storage/paid Licensed panel, About top inspected. Paid license recognized without resetting/re-entering it. Actual red close button removed Settings while app stayed alive; subsequent normal Quit ended old log23:01:49.660Z. Final new screenshots still in progress; do not claim all Clip flows or a public2.3.24 release.
- Shared SaneUI81982cd6e6f16895aae00859782087aecf25dd44 restores native content scroll indicators in existing SaneSettingsPage (one line, sidebar unchanged). Published and exact Air/Mini;3 existing package tests pass. Before, Clip About exposed no AX scrollbar; rebuilt About exposes settable scrollbar, actual value1 scroll succeeded, screenshot19:05:14 shows complete Links/Donate bottom with filled pink hearts. Physical focus attempts/old absent scrollbar were not successful proof.
- CRITICAL wrapper repair: routine launch previously reset dev-alias Accessibility and attempted stale TCC-row DELETE/tccd restart unconditionally. Removed automatic call and99lines of unused private helpers in test_mode.rb. Updated existing actual launch harness rejects reconciliation; fixed25/25 pass, old-source control23/25 with both launch cases failing exactly at forbidden reconciliation. Both changed files exact Air/Mini. New actual Clip launch has no TCC-repair step. Old ignored command statuses mean actual prior TCC mutation success remains unproven. Separate sane_test repair flags are explicit opt-in and were not used.
- Logged Clip focused regressions: LicenseGateWindowTests1/1 d96013fae7ddd46a74614a6352acdcbd and NonBlockingKeychainServiceTests4/4 e7e0a4646bff332e40b20f6cb415e9b5. Both logs survived until explicit stop after tests, closing the verify-reaper runtime gap.
- Clip reconciliation:12 reviewed source/test/project/pin files exact Air/Mini, with every prior file backed up; .saneprocess unit_dir corrected alone while unrelated Air App Store metadata preserved. PBX semantic comparison proved only version/build, published SaneUI replacement and three reviewed file registrations. Receipts clip-settings-visual/{air-sync,pbx-semantic-diff,source-manifest,followup-manifest,scrollbar-repin}.json.
- Cite PR7 updated head5e1a4afd8eb7335ed076793de2d04ede77ae563d: pypdf6.17.0, parser identity2026-09-06.1-security, Wrangler4.129.0, native macOS test-library/Brave routing, and existing Enterprise schema initialization before fail-closed SSO lookup. Local13 parser groups/142 Node-browser/62 real SQLite/0 npm advisories. PR CI34065204146 fully green; saved predeploy merge tree12f063797ea442d96b1c71f21b8076f43c183531 exactly matches reviewed candidate. Real8page/60row PDF and Worker-parser artifacts verified by CI receipts.
- Cite live Worker remaineda0d4669c-c6c5-4dea-8fd6-d86a0ca6ee07 and main9c0c301 before merge. PR merged23:01:27Z as3e9c3f4d0d962aaa420e4bfe0449114e97c32cb9. Canonical main run34065679512: verify green, deploy IN_PROGRESS at Worker/parser attestation. Do not claim deployment success until final attestation/live/recovery receipts are inspected. No AI activation/billing-policy changes or customer sends.

## Active repair — 2026-09-06
- Owner reports expired-trial window cannot close and paid SaneClip is unrecognized after reboot.
- Confirmed shared SaneUI pin 7f87b04 removes .closable and terminates on disappearance. Published 8568997 has both the closable gate and non-interactive Keychain fallback fix.
- Production defaults still contain saved license credential and validation metadata; values were not displayed. Old pinned keychain ignores this fallback on missing/inaccessible keychain reads. Paid runtime state confirmed below by normal signed launch.
- Updated project.yml to published 8568997; retained gate window safely for deliberate reopening. Added hosted close/reopen/no-unlock regression. Corrected tests.unit_dir to existing Tests directory.
- Pre-change Mini desktop screenshot: /tmp/saneclip-startup-sample-20260906.txt is a process sample (main event loop healthy). Screenshot /var/folders/k3/rv4pdt_93w96djzjnsyszgl40000gn/T/codex-shot-2026-09-06_02-36-00.png shows desktop only; it does NOT verify the gate.
- Verification: canonical verify f93a43db1880d25bdb320ecf2dbe133e ran 251 tests; hosted close/reopen/no-unlock and package-pin tests PASS. Two pre-existing website-copy tests remain red (live 2.3.23 vs source 2.3.24 and bundle copy). Focused monitor lane failed before tests because Debug provisioning is unavailable; the canonical unsigned verify lane succeeded for changed tests.
- Installed signed Release 2.3.24 via canonical launch f72abcd1c7aac3c6766c412bd0ef9a7a; codesign --verify --deep --strict passed. At 02:44:14 startup log reports License valid (offline grace, 3d since check), Settings license service seeded with isPro=true. No new license key or reset used. Live log: outputs/license-gate-20260906/live.log.
- Pending: clean real-app close/Quit and settings screenshots. Screen Sharing rejects saved credentials; controller CUA subsequently timed out twice. Do not claim full visual proof or release-ready. No public release, commit, or push performed.
- All-app audit: corrected SaneSync stale shared pin (62 tests pass) and SaneHosts conflicting package lock (close regression passes; unrelated copy assertion remains red). SaneClick already consumes a closable gate. No equivalent gate caller found in current SaneBar, SaneSales, SaneVideo, or SaneBooks source; SaneScan paywall has Done, and SaneLot dismissal lock is limited to saving an edit. This is a source audit, not complete live UI proof across apps.
- Maintenance: coding-client updates completed where available; TestFlight blocked by Apple billing, custom-tap tools unverified. Normal restart hang cause remains unproven; details in SaneProcess handoff and outputs/keep-current-20260906.json.
- Stopped this task's log helper after verification; production SaneClip PID31120 preserved. Screen Sharing sign-in remains the next step for visual verification.

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

## 2026-09-06 shared license-feedback dependency

- SaneUI0f04e753 parent-approved3-file repin prepared from8568997; no resolve/build/test yet. Nearest regressions: hosted LicenseGateWindowTests plus4NonBlockingKeychainServiceTests. Actual paid/expired/close customer visual proof remains parent-owned. Existing earlier website-copy failures are independent of the gate patch; do not advertise unshipped versions to turn those green.
- Custody and exact patch: SaneProcess outputs/portfolio-review-20260906/license-entry-feedback/SaneClip-repin/.


### Clip focused assertions and runtime evidence defect — 2026-09-06 20:10 UTC

Clip Mini three-file SaneUI repin to 0f04e7536ca69ef684ef6835034d4916ccdbfd84 resolved successfully; only SaneUI changed in the dependency lock. Canonical verify with SANEMASTER_TEST_TARGET, --no-grant-permissions, --timeout 300 and all four no-prompt/cache flags compiled and passed LicenseGateWindowTests 1/1 (expiredGateCanCloseWithoutUnlocking), then NonBlockingKeychainServiceTests 4/4 (passthrough, stalledReadDegradesToNil, stalledWriteThrows, innerErrorsPropagate). Exact xcresult test trees independently confirmed those five names Passed. Gate fixtures use private UUID defaults and fake keychain; no real paid key, permission reset, activation or release.

Receipts relative to SaneClip: outputs/verify/20260906T200713.253068Z-63725-4c5ac507/01-test.xcresult (workflow 362193a3ae02239d245a7e0c4cad5631) and outputs/verify/20260906T200847.196143Z-64641-bd26814e/01-test.xcresult (workflow 90631375a022255ecce53af91b42948f). Logs adjacent.

Required native runtime evidence is INVALID: both captures were ready before launch but verify preflight killed them before the test phases. Runtime receipts outputs/runtime-logs/20260906T200709Z-20260906-63722-pi88cb/receipt.json and 20260906T200845Z-20260906-64630-na4ocp/receipt.json say state=failed, log stream exited. Second verify explicitly reaped log PID64639. Root cause: SaneProcess scripts/sanemaster/verify.rb:445 uses pgrep -f xctest, then accepts arbitrary command text containing SaneClip; the log stream predicate contains both. terminate_project_test_processes uses the same unsafe selector. Fix real executable/ownership selection; do not rename predicates to evade it. Saved run-fixture.rb also needs final capture-state checking before reuse. No unchanged retry. Operational memory e2d2da03-b601-4d71-9fca-21c84e4c9d62 revision1253.

All test/resolver/capture processes exited. Mini screenshot 16:10:44 shows clean Finder desktop without app windows or prompts (Air outputs/portfolio-review-20260906/license-entry-feedback/clip-post-fixtures-desktop.png). Parent owns next runtime slot. Assertions/compile are green; complete logged verification and real paid/expired visual proof remain pending.

Sales Mini resolve completed20:09:44Z; only SaneUI lock changed. Its three files now match Air by exact SHA256 after before-hash preconditions. Video previously completed the same three-pin parity. Clip Air synchronization stopped before edits because its baseline differs: yml old7f87b04/version2.3.23, generated local SaneUI package, no remote lock, missing Mini gate/keychain source registrations. Requires reviewed source reconciliation, not wholesale overwrite. Exact custody/patches under outputs/portfolio-review-20260906/license-entry-feedback/{SaneClip,SaneSales}-repin/. Clip patch SHA256 deace48be2b5bef79d0c259665faff1d18812d9fb51bc6d40d36a70efd6995f0; Sales 06e6c579d98188f037460627ec8f79f065593ebd3d53809ecbc3a037c000382d. No app release or Air build.
