# Session Handoff - SaneClip

Active handoff only. Older capture/App Store/pricing notes were compacted on
2026-05-21 to keep startup context small. Durable history remains in git,
`CHANGELOG.md`, `ARCHITECTURE.md`, Serena memory, and the knowledge graph.

## Current State

### 2026-07-07 ~00:55 - Glenn #1034 follow-up reviewed; appcast live repaired; focus fix source verified

State: Glenn's follow-up email #1034 was reviewed through `check-inbox.sh review
1034`. Attachments were saved/opened under
`~/Desktop/Screenshots/email1034-att328-1zm0s5ws.png`,
`email1034-att329-z3nrne1i.png`, and `email1034-att330-fg45qqls.png`.
Diagnostics showed SaneClip `2.3.18 (2318)` on macOS `26.5.2`.

Findings:
- Fixed-history keep-open paste left the already-visible NSPopover unfocused
  after paste. Screenshot `att328` shows the dim/unfocused history window;
  `att329` shows the same window focused.
- In-app direct updates were failing with Sparkle
  `SUSparkleErrorDomain code=1000` parse errors. The appcast was XML-valid, but
  the legacy no-enclosure informational `2.2.12` item lacked top-level
  `sparkle:version` / `sparkle:shortVersionString`, which Sparkle expects for
  manual-download appcast items.

Implemented:
- `SaneClipAppDelegate+HistoryWindow.swift`: fixed popover keep-open paste now
  restores focus after paste via a fixed-popover-only helper that activates
  SaneClip and calls `makeKeyAndOrderFront(nil)`. Floating history remains on
  the non-activating path and must not call `NSApp.activate`.
- `docs/appcast.xml`: legacy informational `2.2.12` now includes
  `sparkle:version` `2212` and `sparkle:shortVersionString` `2.2.12`.
- SaneProcess shared guardrails now block informational Sparkle appcast entries
  missing top-level `sparkle:version` in both per-app release preflight and live
  fleet validation. This applies to all direct/Sparkle apps, not just SaneClip.
- Website-only deploy completed and verified live `https://saneclip.com/appcast.xml`.

Verification:
- `ruby scripts/sanemaster/release_guardrail_test.rb` passed 170/170 in
  SaneProcess.
- `ruby scripts/validation_report_test.rb` passed 73/73 in SaneProcess.
- `xmllint --noout docs/appcast.xml` passed.
- Local and live appcast audit: SaneBar, SaneClick, SaneClip, SaneHosts,
  SaneSales, SaneSync, and SaneVideo are HTTP 200, XML-valid, have latest
  enclosure metadata, and have no informational entries missing
  `sparkle:version` or required manual links.
- `./scripts/SaneMaster.rb verify --timeout 900 --no-grant-permissions` passed
  222 tests after the test-slice correction.
- `./scripts/SaneMaster.rb release_preflight` passed with warnings only:
  6 uncommitted files, 37 pending customer emails, and evening timing. Technical
  gates were green, including live appcast/download/Homebrew/webhook checks and
  222 tests.
- `./scripts/SaneMaster.rb appstore_preflight` passed with warning only:
  6 uncommitted files. ASC lanes, IAP, signing, policy guardrails, target graph,
  compiled artifact audit, metadata, and 222 tests were green.
- `./scripts/SaneMaster.rb setapp_status --json --soft` could not verify live
  portal status because there is no current Mini Safari developer session or
  `SETAPP_PORTAL_TOKEN`. The repo still has SaneClip Setapp config for app ID
  `1847`, version ID `47647`, bundle ID `com.saneclip.app-setapp`, scheme
  `SaneClipSetapp`, and listing screenshot metadata.
- `ruby ~/SaneApps/infra/SaneProcess/scripts/sane_test.rb SaneClip --release
  --pro-mode` staged and launched the canonical Developer ID app at
  `/Applications/SaneClip.app`.
- First `customer_ui_sweep` was blocked by visual contamination from QuickTime
  and a stale SaneClickExtension helper; both were cleared. Rerun passed with
  transcript `outputs/customer-ui/sweep-20260707T005333Z/customer-action-runtime.log`,
  live log `outputs/live-logs/customer_ui_saneclip_20260707T005123Z.log`, and
  visual smoke receipt
  `outputs/visual_smoke/visual_smoke_20260706-205157_63599/receipt.json`.

Release caveat: the appcast parse error is fixed live. The fixed-history focus
change is source-verified and locally staged, but it is not in a public binary
until the next direct/App Store/Setapp build is submitted. Setapp live status is
auth-blocked until portal credentials/session are restored.

### 2026-07-05 ~10:30 - Glenn #1016 evidence reviewed; code and visual proof green

State: Xcode 26 attempted project/scheme "recommended settings" changes that
were not safe to keep. The accidental `project.pbxproj` churn changed signing
toward Automatic/Apple Development in direct/debug lanes and blanked some team
settings. Regenerating from `project.yml` restored the generated project source
of truth; the remaining Xcode project/scheme diffs are generated metadata plus
target buildable-name corrections. The intentional project-source change is
`ENABLE_DEBUG_DYLIB: NO` for the main SaneClip target; without it, Xcode 26 set
`ENABLE_DEBUG_DYLIB=YES`, and `SaneMaster.rb verify` failed linking
`SaneClipTests` because `SaneClip.app/Contents/MacOS/SaneClip.debug.dylib` was
missing.

Glenn #1016 review is complete through the guarded inbox path. Attachments were
saved under `~/Desktop/Screenshots/email1016-*`: three footer/hover screenshots,
`SaneClip.mov`, and diagnostics. The screenshots/video confirm the reported
fixed-window Merge Queue + Paste Stack footer crowding and minimum-width hover
row instability in SaneClip 2.3.15 (2315). Diagnostics showed
`accessibilityGranted: true`, `historyCount: 12`, and `pasteStackCount: 1`.

Current local source now has fixes and guards for:
- Merge Queue and Paste Stack split into separate footer rows when both exist.
- Hover rows no longer add inline stats; stats are tooltip-only, and shortcut
  badges stay one line.
- Floating and fixed keep-open paste paths keep the history surface visible
  while clearing key status before synthetic paste.
- Fixed keep-open paste now requests front/key restore for an already-visible
  popover after paste via `makeKeyAndOrderFront(nil)`. Do not overclaim
  `isKeyWindow` proof from XCTest; `_NSPopoverWindow.isKeyWindow` stayed false
  in the test host even after the documented AppKit restore call.
- Non-keep-open fixed-popover paste temporarily disables popover animation
  before `close()` so the popover is actually hidden before Cmd+V.

Fresh support/status pass:
- `check-inbox.sh read 1016` / `review 1016` confirmed Glenn's 2026-07-05
  06:12:06 UTC message (2:12 a.m. Eastern) plus three screenshots,
  `SaneClip.mov`, and `Diagnostics.txt`.
- Video was re-read from the fresh attachment: 20.31s, 872x1402; the
  regenerated contact sheet shows the minimum-width hover row instability.
- `check-inbox.sh check` still shows #1016 as Glenn's newest SaneClip thread,
  with #1012/#1007 as older related duplicates.
- `gh search issues --owner sane-apps --state open` returns no open SaneClip
  issue; the only support-scoped open issue is unrelated SaneClick #6.
- Glenn's drag-order note is classified separately: current code supports
  pinned-item reorder and Paste Stack reorder, while Recent rows use drag-out to
  other apps. Do not describe arbitrary Recent-history reorder as fixed unless
  that feature is explicitly added.

Verification:
- `./scripts/SaneMaster.rb verify --timeout 900 --no-grant-permissions` passed
  220 tests after the fixed-popover focus-contract correction.
- `./scripts/SaneMaster.rb customer_ui_sweep` passed with receipt generated
  `2026-07-05T14:28:55Z`, 12 covered action IDs, and structured coverage only
  for live paste completion. Live log:
  `outputs/live-logs/customer_ui_saneclip_20260705T142644Z.log`; transcript:
  `outputs/customer-ui/sweep-20260705T142855Z/customer-action-runtime.log`;
  visual smoke:
  `outputs/visual_smoke/visual_smoke_20260705-102718_45359/receipt.json`.
- `./scripts/SaneMaster.rb release_preflight` passed with caution: 20
  uncommitted files and 36 pending customer emails. Do not call the release
  clean until those warning categories are intentionally accepted or cleared.
- `git diff --check` passed.

### 2026-07-05 ~06:10 - Superseded Glenn #1016 first-pass fix notes

State: `SaneMaster.rb status` surfaced new Glenn email #1016 and SaneClip
release drift: Lemon Squeezy still hosted 2.3.15 while appcast/direct expected
2.3.16, and launch readiness remained no-go. `check-inbox.sh review 1016`
completed and opened all five attachments: four screenshots/video plus
diagnostics. Glenn was running SaneClip 2.3.15 (2315), with Accessibility
granted, `historyCount: 12`, and `pasteStackCount: 1`.

What was fixed from #1016:
- Narrow history footers now split Merge Queue and Paste Stack controls into
  separate rows when both are active, so counts/actions stay visible at the
  fixed 320px history width.
- Clipboard row hover no longer injects inline stats that reflow the row; stats
  remain available as a tooltip, and the shortcut badge stays one line.
- Added the 320px Pro merge+paste-stack render scenario:
  `matrix-13-pro-popover-merge-stack-320x500.png`.

Superseded by the 10:05 entry above: the visible keep-open path has now been
changed and verified for both floating and fixed history. Keep this section only
as context for why the later no-hide AppKit fix needed extra proof.

Release caveat: this is a source fix only. The project is still at 2.3.16
(`2316`), and the existing `releases/SaneClip-2.3.16.zip` was built on
2026-07-04 before these changes. Bump to 2.3.17+ before shipping; do not rebuild
or advertise this fix as the already-published 2.3.16 artifact.

Verification:
- `./scripts/SaneMaster.rb verify --timeout 900 --no-grant-permissions` passed
  217 tests after the code/doc/appcast fixes.
- `ruby ~/SaneApps/infra/SaneProcess/scripts/sane_test.rb SaneClip --release
  --pro-mode` built, staged `/Applications/SaneClip.app`, preserved TCC,
  launched PID 33333, captured SaneClip logs, and the test instance was quit
  afterward.
- Screenshot-enabled verify passed 217 tests and generated receipts under
  `/tmp/saneclip_glenn1016_render/`; visual check of
  `matrix-13-pro-popover-merge-stack-320x500.png` showed Merge Queue and Paste
  Stack split into separate footer rows at 320px.

### 2026-07-04 ~11:50 - SaneClip 2.3.15 direct/Sparkle ship complete; Glenn draft awaiting approval

State: SaneClip 2.3.15 is fully live on the direct/Sparkle channel and the
known-bad Apple submission has been replaced. Apple build `2315` is attached to
ASC version `ffb9aca2-9956-4d3d-9096-0e0742f21c74` with submission
`ff4be602-730e-47a4-9f9c-f2a37dca5744`; latest confirmed state was
`WAITING_FOR_REVIEW`.

Direct-channel receipts:
- Full Developer ID release completed after abandoning invalid `--skip-build`
  resume attempts that found empty archive products. Notary submission
  `bb216353-aa09-4710-b1e7-af0c4af746ce` was accepted and stapled.
- GitHub release `sane-apps/SaneClip@v2.3.15`, R2 ZIP
  `https://dist.saneclip.com/updates/SaneClip-2.3.15.zip`, appcast build
  `2315`, website JSON-LD version `2.3.15`, redirect
  `https://go.saneapps.com/download/saneclip`, and the live email webhook all
  verify against 2.3.15.
- Public ZIP SHA256:
  `1da75ea5b9e6dff9c3fb189e8c8e8e661d27c58b2d17f5bbbaee6c8fbd79f386`;
  length `5196756`.
- Homebrew tap commit `3626fba` has the correct cask via GitHub API; raw GitHub
  may lag briefly from propagation only.
- Lemon Squeezy product `779223`, variant `1228215`, now has exactly one
  published hosted file: `SaneClip-2.3.15.zip`. The stale `2.3.13` file was
  deleted in Safari after user confirmation. Fresh
  `SaneMaster.rb hosted_file_actions --json` shows SaneClip status `In sync`.

Final verification after Lemon Squeezy cleanup:
- `bash /Users/stephansmac/SaneApps/infra/SaneProcess/scripts/release.sh --project
  /Users/stephansmac/SaneApps/apps/SaneClip --version 2.3.15
  --post-release-checks-only` passed at `2026-07-04T15:48:43Z`.
- Post-release probe:
  `outputs/release/post-release-probes-20260704T154843Z-97588.txt`.
- Hosted-file receipt:
  `/Users/stephansmac/SaneApps/infra/SaneProcess/outputs/hosted_file_actions/post-release-saneclip-2.3.15-20260704T154843Z-97588.json`.

Glenn reply is prepared but not sent. Email #1013 was reviewed, reconciled, and
fact-verified against the two release receipts. Presented draft:
`/tmp/reply_1013.txt`, SHA256
`4ae086a91e3dd6c35422855f9fa265f274ae8855d559fb2386abdc95ce367730`.
Do not send until the user explicitly approves that exact draft; then run
`check-inbox.sh approve /tmp/reply_1013.txt --user-approval "<exact quote>"`
and `check-inbox.sh reply 1013 /tmp/reply_1013.txt`.

### 2026-07-04 ~10:20 — Glenn #1012/#1013 2.3.15 replacement submitted after isolated Mini proof

State: Glenn reported three fresh 2.3.14 regressions after the July 4 release:
floating keep-open/pinned history did not paste into the target app, fixed
keep-open did not stay open after paste, Merge Queue state disappeared across
floating/fixed close/switches, and Pause Capture countdown froze until a new
pasteboard event. Threads reviewed with `check-inbox.sh review`: #1013,
#1012, #1007, #994. Do not reply or resolve without the normal review/hash
approval gate.

Root causes fixed in code:
- Floating keep-open returned early from `handleDismissForPaste`, leaving the
  non-activating history panel visible/key during Cmd+V. It now always orders
  the panel out before synthetic paste; reopen is handled by the existing
  `.reopenHistoryAfterPaste` notification.
- Merge Queue IDs lived in `ClipboardHistoryView @State`, so recreating the
  floating/fixed hosting view lost the footer/count. The queue is now shared
  manager state and is pruned on delete/clear.
- Pause countdown was computed from `Date()` but no observable value changed
  while the pasteboard was idle. The monitor timer now refreshes an observable
  countdown tick before the unchanged-pasteboard early return.
- Paste success sound no longer plays before `simulatePaste()` succeeds, and
  direct builds no longer reopen keep-open history after a failed paste
  simulation, so a blocked paste cannot sound or look successful.
- Merge Queue IDs are now pruned when history entries disappear through delete,
  clear, history-limit trim, expiry cleanup, and sync deletion/trim. The
  executable regression test covers trim/expiry; source review covers the sync
  paths because they compile only in sync-enabled builds.

New durable gates:
- `./scripts/SaneMaster.rb verify --timeout 900 --no-grant-permissions`
  passed 215 tests on the Mini after the 2.3.15 version/project regeneration;
  rerun after the proof-gate correction before shipping. Key tests now include:
  `Floating keep-open orders history out before synthetic paste`, `Merge queue
  selection is shared state so it survives history view recreation`, `Merge
  queue drops IDs for items removed by trim and expiry`, `Customer UI proof
  sweep does not fake Mini click completion`, `Pause capture countdown
  invalidates from the monitor timer`, and `Paste success sound waits for
  simulated paste success`.
- Glenn visual receipts regenerated via `/tmp/saneclip_screenshot_dir.txt` into
  `outputs/capture-renders/`: `glenn-1012-floating-reopened-merge-queue-retains-3.png`,
  `glenn-1012-fixed-switch-merge-queue-retains-3.png`,
  `glenn-1012-keep-open-pin-visible-before-paste.png`, and
  `glenn-1013-pause-countdown-visible-while-idle.png`.
- `Tests/CustomerUIActions.yml` now explicitly requires the missed classes:
  keep-open floating/fixed focus handoff, Merge Queue persistence across view
  recreation/mode switch, and idle Pause Capture countdown decrement. It no
  longer claims live TextEdit receipt unless that proof actually exists.
- `scripts/customer_ui_action_sweep.rb` now routes the affected actions to
  Glenn-specific screenshots and hard-fails if those screenshots are missing.
  It now refuses `mini_click` evidence, records the actual Mini hostname, and
  writes `coverage_status: covered`, `covered_assertions`, and `steps_covered`
  instead of per-action completed/passed claims. Final sweep after rebuild/launch
  refreshed
  `.sane/customer_ui_action_receipt.json`; runtime log
  `outputs/live-logs/customer_ui_saneclip_20260704T134735Z.log`; visual smoke
  receipt `outputs/visual_smoke/visual_smoke_20260704-094842_23241/`;
  customer sweep transcript
  `outputs/customer-ui/sweep-20260704T135018Z/customer-action-runtime.log`.

Important proof correction: the earlier failed live-click attempt under
`outputs/live-click-proof-glenn-1012-1013-20260704-0845/` remains invalid and
must not be cited. After the MacBook Air was turned off, a valid isolated Mini
TextEdit proof was captured under `outputs/live-proof/glenn-20260704T140729Z/`:
SaneClip 2.3.15 (2315) captured sentinel
`GLENN_KEEP_OPEN_PASTE_PROOF_20260704T140739Z` in the sandboxed history at
index 0, opened floating SaneClip History over TextEdit while TextEdit stayed
frontmost, pasted the sentinel via Return from the selected history row, and
kept SaneClip History open with the pin active. Key screenshots:
`05-history-open-before-return.png` and `06-after-return-paste.png`. The same
proof folder also shows Pause Capture countdown moving from `4m 59s` to
`4m 56s` while idle, then capture resumed in `10-capture-resumed-cleanup.png`.

The macOS App Store 2.3.14 lane was withdrawn on 2026-07-04 after it was known
bad (`WAITING_FOR_REVIEW` -> `DEVELOPER_REJECTED`), then retargeted with
`appstore_submit.rb --preflight-version-state --repair-version-state` so the
editable macOS lane is now 2.3.15 (`DEVELOPER_REJECTED`) and iOS 2.3.15 is
clear. 2.3.15 is the intended replacement patch release for these regressions.
Fresh coverage/evidence after the proof-gate correction:
- `./scripts/SaneMaster.rb verify --timeout 900 --no-grant-permissions` passed
  217 tests on 2026-07-04.
- After the Air-off isolation step, `./scripts/SaneMaster.rb verify --timeout
  900 --no-grant-permissions` passed again with 217 tests, and final
  `./scripts/SaneMaster.rb appstore_preflight` returned `ALL CLEAR — ready for
  App Store submission`.
- `./scripts/SaneMaster.rb customer_ui_sweep` passed on 2026-07-04 with
  receipt `.sane/customer_ui_action_receipt.json`, host
  `Stephans-Mac-mini.local`, version 2.3.15 (2315), and visual smoke receipt
  `outputs/visual_smoke/visual_smoke_20260704-094842_23241/`; receipt generated
  `2026-07-04T13:50:18Z` with the corrected coverage schema.
- Air-off `customer_ui_sweep` passed again with visual smoke receipt
  `outputs/visual_smoke/visual_smoke_20260704-100433_54965/` and sweep
  transcript `outputs/customer-ui/sweep-20260704T140610Z/customer-action-runtime.log`.
- `./scripts/SaneMaster.rb release_preflight` passed at
  `2026-07-04T09:52:58-04:00` with expected warnings: uncommitted files,
  UserDefaults/migration change notice, pre-publish appcast/Homebrew still on
  2.3.14, and 36 pending emails.
- `./scripts/SaneMaster.rb appstore_preflight` passed at
  `2026-07-04T09:54:45-04:00` after the ASC retarget, with only the
  uncommitted-files warning.
- `appstore_submit.rb` uploaded `build/Export-AppStore/SaneClip.pkg`; Apple
  processed build `2315` as build ID `aac49749-0108-40ec-8ef0-679b8662732e`,
  attached it to ASC version `ffb9aca2-9956-4d3d-9096-0e0742f21c74`, and
  submitted it for review. macOS SaneClip 2.3.15 is now `WAITING_FOR_REVIEW`.
Before replying to Glenn, say the fix is submitted/in review and ask him to
retest once available. Still watch the Lemon Squeezy hosted-file gate during
direct release; this Apple replacement did not deploy the direct ZIP/LS file.

### 2026-07-04 ~05:25 — 2.3.14 direct release mostly live; Lemon Squeezy hosted file still blocks final completion

State: SaneClip 2.3.14 direct-channel release ran from the Mini and published
the signed/notarized ZIP to the public channels, but the release script stopped
at the Lemon Squeezy hosted-file post-release gate. Do not rerun the full
release for this; the script explicitly requested hosted-file sync followed by
post-release checks only.

Live/published direct-channel receipts:
- GitHub release/tag: `v2.3.14`; direct ZIP uploaded.
- Dist URL verified during release:
  `https://dist.saneclip.com/updates/SaneClip-2.3.14.zip`.
- ZIP SHA256:
  `837257f807f6b85e1634b6df94f1eedce7d79e1d6e9c6beebcccc7b585d6edb0`.
- Appcast updated and propagated with exactly one 2.3.14 entry.
- Cloudflare Pages deploy completed (`saneclip-site` preview:
  `https://c076a528.saneclip-site.pages.dev`).
- Homebrew tap updated to 2.3.14 (`sane-apps/homebrew-tap` commit `ded3b0a`).
- Email webhook deployed live with SaneClip 2.3.14 bundle mapping
  (`sane-email-automation` commit `f9a8b19`).

Blocking direct-channel follow-up:
- Lemon Squeezy hosted file for product `779223`, variant `1228215`, still
  reports hosted `2.3.13` while appcast expects `2.3.14`.
- Local upload staging is ready:
  `/Users/stephansmac/Desktop/LemonSqueezy-Uploads/SaneClip-2.3.14.zip`.
  The stale local `SaneClip-2.3.13.zip` staging copy was removed.
- Chrome is open to the Lemon Squeezy login page and is not authenticated. Sign
  in, replace/unpublish old hosted files so only the appcast-matching 2.3.14 ZIP
  is published, then run:
  `bash /Users/stephansmac/SaneApps/infra/SaneProcess/scripts/release.sh --project /Users/stephansmac/SaneApps/apps/SaneClip --version 2.3.14 --post-release-checks-only`.
- Hosted-file receipt:
  `/Users/stephansmac/SaneApps/infra/SaneProcess/outputs/hosted_file_actions/post-release-saneclip-2.3.14-20260704T045743Z-86761.json`.

App Store channel:
- Customer UI sweep reran after release metadata commits and passed, refreshing
  `.sane/customer_ui_action_receipt.json` at `2026-07-04T05:10:45Z`.
- Visual proof artifacts:
  `outputs/visual_smoke/visual_smoke_20260704-010907_91831/screen.png`,
  `outputs/visual_smoke/visual_smoke_20260704-010907_91831/menu.png`, and
  live log `outputs/live-logs/customer_ui_saneclip_20260704T050834Z.log`.
- `./scripts/SaneMaster.rb appstore_preflight --json` passed: all clear for
  App Store submission.
- macOS App Store build `2314` uploaded, processed, attached to version 2.3.14
  (`appStoreVersion` ID `ffb9aca2-9956-4d3d-9096-0e0742f21c74`, build ID
  `96143641-2098-4048-9a56-37daa57f4ca2`), screenshots/metadata synced, and
  review submission reached `WAITING_FOR_REVIEW`.
- Commit pushed after the release metadata commits:
  `23cda7d chore: refresh SaneClip customer UI receipt`.

### 2026-07-04 ~03:52 — 2.3.14 release-readiness audit green, not shipped

State: Mini-first audit/release prep completed for SaneClip 2.3.14. `release_readiness --json --app SaneClip` is green with no candidate or portfolio blockers. `release_preflight --json` passed after fixing stale docs and privacy-cache behavior; warnings remain: dirty worktree, UserDefaults/migration upgrade-path warning, appcast/Homebrew still live at 2.3.13 until publish, 34 pending emails, and evening release timing. `appstore_preflight --json` also passed; only warning was dirty worktree.

Changes made in this pass: documented 2.3.14 in `README.md` and `CHANGELOG.md`, corrected the README macOS badge to 14.0+, consolidated duplicate 2.3.9/2.3.8 changelog headings, updated public privacy/encryption copy, fixed stale `customer_ui_action_sweep.rb` Snippets Pro guard, and closed the security audit finding where encrypted history still left plaintext widget/iOS app-group caches. Follow-up release-note completeness pass added the rest of the 2.3.14 customer-facing upgrades: paste-into-app/first-click behavior, keep-open flicker removal, bulk merge-queue delete, trailing-newline cleanup, broader tracking cleanup, icon-cache scrolling, hover/drag tracking, and staged localizations. New tests in `Tests/SecurityTests.swift` cover shared-cache withholding and source ordering.

Proof receipts:
- Customer UI strict contract: `.sane/customer_ui_action_receipt.json`, generated `2026-07-04T03:43:30Z`, 12 actions, no issues.
- Runtime cycle: `ruby ~/SaneApps/infra/SaneProcess/scripts/sane_test.rb SaneClip --release --pro-mode` launched `/Applications/SaneClip.app` as the single canonical Developer ID-signed copy on the Mini.
- Visual proof matrix: `outputs/visual-audit-release-ready-20260704-034510/` with `proof-index.md`; inspected merge footer, edit sheet buttons, Clipboard Rules toggles, floating preview/actions, Paste Stack recording, and settings/security surfaces.
- Tests: multiple `./scripts/SaneMaster.rb verify --timeout 900 --no-grant-permissions` runs passed 210 tests; release/appstore preflights reran tests too.

Operational fix outside this repo: `sane-email-automation` clean temp clone commit `7bbc101` updated the SaneClip bundle webhook signed-download mapping to `SaneClip-2.3.13.zip`; deployed Worker version `7962ee3f-c6a9-48c3-a2c2-c1fc56b1e6fe`. Live Worker check returned SaneClip `2.3.13` / `2313`.

### 2026-07-03 ~23:00 — DAY'S WORK + INDEPENDENT VERIFY GUIDE (run on the Mini directly)

State: `main` @ `14f68ef`, **Air ↔ Mini synced**, 208 tests green. **origin (GitHub) NOT pushed** (stuck at `7e0e72c` — publish decision, owner's call). Everything under the ~16:00 note below is superseded history.

Build + full suite (expect `208 tests ... passed`):
```
cd ~/SaneApps/apps/SaneClip && xcodebuild test -scheme SaneClip -destination "platform=macOS" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO 2>&1 | grep -iE "Test run with|✘|\*\* TEST"
```
Build + launch real app: `ruby ~/SaneApps/infra/SaneProcess/scripts/sane_test.rb SaneClip --release --local --pro-mode`

What shipped today + how to verify each:
1. **Paste-into-app fix** (Glenn #1007, `ad001cc`) — clicking a row auto-pastes into the app you were typing in, no focus steal. Root cause: `.nonactivatingPanel` defaults `canBecomeKey=false` → first click swallowed; fix = `NonActivatingHistoryPanel` forces `canBecomeKey=true`. Verify hands-on: type in TextEdit, copy, open history (⌃⌘⇧Y), click a snippet → pastes into TextEdit. (Proven 3/3 with a disambiguating live test.)
2. **Pin-eviction data-loss fix** (`07a8d07`) — `enforceHistoryLimitIfNeeded` now protects pinned IDs (was paste-stack only). Test: `pinnedItemsSurviveHistoryTrim`.
3. **4 Maccy easy-wins** (`547520f`/`e105ce8`/`1a469c3`): #1413 wider tracking strip (test `stripsWidenedTrackingParams`), #1044 "Strip trailing newline" Pro rule (`stripsOnlyTrailingNewlines`), #1416 `Core/SourceAppIconCache.swift` (`iconCacheCachesAndHandlesMissing`), #239 merge-queue bulk delete — red **Delete** in footer (`removeHistoryItemsDeletesSelection`). Tests in `ClipboardTransformsTests` + `HistoryColorAndStackTests`. (#1345 was ALREADY done via `SettingsModel.maxCaptureTextBytes`.)
4. **Localization — 8 languages** (`42402b1`/`6c12417`/`519f192`/`f4fd3f1`/`5bbed80`): 356 strings machine-translated + AI-web-verified into de/fr/es/it/pt-BR/ja/zh-Hans/ko in `Resources/Localizable.xcstrings` (100% coverage, 0 placeholder mismatches, `CFBundleLocalizations` set). Verify a locale renders: `echo /tmp/de>/tmp/saneclip_screenshot_dir.txt; mkdir -p /tmp/de; xcodebuild test -scheme SaneClip -destination "platform=macOS" -only-testing:SaneClipTests/HistoryRenderTests -testLanguage de -testRegion DE CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO; rm /tmp/saneclip_screenshot_dir.txt; open /tmp/de/matrix-03-pro-floating-480x640.png` (swap `de`→`fr`/`ja`/…). 1 known gap: plural "Notes" label unextracted.

DEFERRED (blocked by over-cap core files, won't game the gate): image-perf #1080/#384 (needs `ClipboardImageStore` extracted from 2600-line ClipboardManager.swift); snippet-hotkey #1125 (needs KeyboardShortcuts registration extracted from at-cap SaneClipApp.swift). OWNER-ONLY: ship 2.3.14 via `release.sh`; reply Glenn #1007 (never "fixed"); decide 2.3.14-bundle-vs-2.3.15; push GitHub origin. Full Maccy shortlist in the `maccy-easy-wins-shortlist` memory; long-form verify guide scp'd to Mini `~/SaneApps/apps/SaneClip/outputs/VERIFY-2026-07-03.md`.
- 2026-07-03 ~16:00 CORRECTIVE RE-AUDIT + FIX PASS — 2.3.14 HELD (do NOT ship yet):
  - A 23-agent adversarial verification workflow DISPROVED the earlier "Glenn
    #1007 fully fixed on main" claim. Ground truth on main `7e0e72c`: the
    keep-open focus-steal fix lived ONLY on the unmerged
    `feature/nonactivating-history-panel` branch; main still shipped the
    activating panel + a `didResignActive` observer, a 0.15s `!NSApp.isActive`
    timer, and `applicationDidResignActive` that all closed the window
    BYPASSING the geometry classifier. So Glenn's New bug 1 (toolbar click
    closes window) and New bug 2 (keep-open doesn't stay) were NOT fixed, and
    the tests "covering" them were blind source-fingerprints that asserted the
    buggy mechanism as correct. Tested-the-wrong-path trap, caught pre-ship.
  - FIXED this session, all green on Mini `main`: merged the non-activating
    branch (`9eea6e7`) and COMPLETED it (`a4cc7d4`) by removing the
    deactivation-close paths (on a non-activating panel the app is usually
    inactive while the window is up, so those would slam it shut the instant
    it opened). Dismissal is now solely the geometry classifier; blind tests →
    regression guards. Footer `ViewThatFits` so merge+stack controls never clip
    at 300-320pt, and Settings Pro badges teal→`proUnlock` so teal = only
    "merge" (`7340884`). Split the 909-line `HistoryWindowTests.swift` into
    413 + 284 + 261 (`HistoryColorAndStackTests`, `HistoryRenderTests`), 23
    tests intact, 199 green (`7439eae`).
  - GATE before ship: a LIVE human paste-into-app test on the Mini must confirm
    the non-activating focus behavior (unit-green only; can't be proven by
    static renders or synthetic keys). Then owner ships + drafts the Glenn
    reply (never "fixed"; ask him to confirm).
  - REMAINING (owner's "fix everything" pass): (a) `verify` TCC reset —
    `verify_support.rb grant_test_permissions` runs `tccutil reset` on the
    app's Camera/Mic/ScreenRecording every run (test build shares the RELEASE
    bundle id, so it wipes the installed app's grants and tests a reset state,
    not the real path); proper fix = extract a focused `verify_permissions.rb`
    (file is 848 lines, over the 800 cap) then delete the reset. (b) paste-stack
    relaunch silent image-drop test + fix (needs a `ClipboardManager.swift`
    split, 2607 lines). (c) AppleScript automation so the real window is
    driveable/capturable (fixes the visual-verification gap + serves
    blind/shortcut users). (d) Hook cleanup: visual gate scrapes phantom
    filenames; `sanetools` false positives.

- 2026-07-03 ~11:30 Post-review follow-ups to the corrective pass (Claude review
  of Glenn #994/#1007), staged for a 2.3.14 release — NOT released:
  - NEW attached-sheet guard: a Mini geometry probe proved the edit sheet
    (min 420pt tall) overhangs a 300x360 minimum-size floating window by
    ~92pt — AppKit clamps sheet width to the parent but not height — so the
    sheet's Save/Cancel clicks landed outside `historyWindow.frame` and the
    outside-click path destroyed the window (and the in-progress edit).
    Every dismissal path (click monitors, resign-active observer, 0.15s
    timer, `applicationDidResignActive`) is now fully inert while
    `historyWindow.attachedSheet != nil`, including monitor teardown, so a
    `hidesOnDeactivate` hide mid-modal keeps monitors for the reappearing
    window. Classifier gained a `hasAttachedSheet` parameter; new tests:
    classifier cases, a real NSPanel+sheet overhang test (completion-handler
    `beginSheet` — the async overload suspends until dismissal, see
    research.md), and source fingerprints.
  - CHANGELOG corrected: bf1886e's items were sitting under the already
    shipped [2.3.13] entry, but 2.3.13 shipped WITHOUT them. They now live
    under [2.3.14] - Unreleased (plus the new sheet-guard bullet); 2.3.13
    keeps only what actually shipped plus a known-issues line. project.yml
    bumped to 2.3.14/2314. Owner ships via release.sh from the Mini.
  - Glenn #1007 is still needs_human/unanswered — reply AFTER 2.3.14 ships
    (owner drafts; per policy never claim "fixed", ask him to confirm).
- 2026-07-03 Glenn #994/#1007 corrective pass is implemented after re-reading
  both support threads and the exact screenshots. The 2026-07-02 proof entry
  was stale/insufficient: it rendered static states and did not reproduce
  Glenn's crowded footer or #1007 toolbar-click failure closely enough.
  - Root causes found: the footer fix kept the crowded controls inside
    `ScrollView(.horizontal, showsIndicators: true)`, so the scrollbar could
    still cover `Clear Queue`; floating-window dismissal added a session-level
    `CGEvent.tapCreate` path on top of AppKit monitors, creating an extra
    coordinate route for inside-window clicks; normal history row/list paste
    still called `clipboardManager.paste(item:)`, so the keep-open setting only
    affected paste-stack paths.
  - Current code removes the footer horizontal scroller and gives secondary
    footer controls their own row; removes the CGEvent tap state/path; routes
    row/list history paste through `pasteFromHistory(item:)`; adds a Pro pin
    button beside search/pause; and renames the setting copy to
    `Keep history window open after pasting`.
  - Current proof: `./scripts/SaneMaster.rb verify --timeout 900
    --no-grant-permissions` passed 191 tests on the Mini twice on
    2026-07-03, including
    `Floating history inside toolbar clicks do not dismiss the window`,
    `Footer keeps item count and actions reachable at narrow widths`, and
    `History paste honors the keep-open pin without changing URL-scheme paste`.
  - Fresh visual receipts are in
    `outputs/visual-audit-glenn-994-1007-finish-20260703-095551/`.
    Inspected PNGs:
    `matrix-02-pro-popover-merge-320x500.png` shows `Clear Queue` visible
    without a horizontal scrollbar; `glenn-994-bug2-edit-sheet-buttons-visible.png`
    shows Save/Cancel reachable at 450x420; the Clipboard Rules before/after
    PNGs show immediate toggle redraw.
  - Dynamic live-click proof for #1007 is now captured in
    `outputs/live-click-proof-glenn-1007-20260703-100237/`. The current Pro
    no-keychain runtime opened `SaneClip History` at bounds `[[959, 271],
    [411, 718]]`; raw inside click `1051,321` on the search/top toolbar band
    left the window open (`INSIDE_CLICK_OK`), and raw outside click `924,391`
    closed it (`OUTSIDE_CLICK_OK`). `live-after-inside-coordinate-click.png`
    shows the focused search row with the floating window still visible.
  - SaneClip customer UI receipt was refreshed after the code changes:
    `./scripts/SaneMaster.rb customer_ui_sweep --json` passed, launched a
    fresh signed `/Applications/SaneClip.app`, produced live Peekaboo smoke
    receipt `outputs/visual_smoke/visual_smoke_20260703-095904_90616/`, and
    `./scripts/SaneMaster.rb customer_ui_contract --json --strict-visual
    --no-exit` returned `ok: true` with zero issues.
- 2026-07-01 ~20:00 EDT — **2.3.12 SHIPPED (direct channel)**; supersedes the
  "NOT committed, NOT released" note below. Verified live: appcast top entry
  2.3.12/2312, dist ZIP HTTP 200, website deployed with the new feature cards
  AND corrected shortcuts (⌘⇧⌃Y / ⌘⌃1-9 — the ship audit caught 4 surfaces
  advertising the retired ⌘⇧V). Ship pipeline: preflight PASS after fresh
  customer-UI sweeps, 15-perspective docs audit (2 criticals found + fixed
  same hour: hotkey copy, and a Touch ID gate bypass on the hotkey/Dock-reopen
  paths — fixed 24e3903 with a pure tested gate), critic consciously skipped
  per owner (3 prior adversarial passes), HMAC clearance written, released
  FROM THE MINI (release.sh must run there: ASC_AUTH_KEY_PATH, Developer ID
  cert, and notary profile are Mini-local — an Air run fails on the ASC key
  path). Release metadata commits on main (6f4f7ae, 09123b7). Post-release
  checks ALL GREEN incl. owner's LemonSqueezy upload (hosted file verified
  2.3.12). Glenn reply SENT + delivered (Resend 5ff41254, thread #983 pending
  his confirmation — do not resolve until he confirms).
  Routing root-cause fixed in SaneProcess (8e80a65): non-release routed
  commands now run in scratch workspaces so canonical Mini repos stay clean —
  ends the dirty-peer release blocks and auto-reconcile stash era.
- 2026-07-01 late — iOS companion upgrades (drag-out, ClipShareLink + Pinned
  Unpin/Delete parity, iPad hardware keyboard nav) MERGED to main from
  `feature/ios-companion-upgrades` (91b3e81), sim-verified on iOS 26.5 with
  fresh iPhone/iPad screenshots in docs/images. App Store (macOS+iOS) and
  Setapp 2.3.12 submissions IN PROGRESS per owner ("both"). Listing copy stays
  conservative on iPad drag/keyboard until the human pass (task #24).
  OPEN: hero screenshot replacement; human iPad-drag/keyboard/auto-paste pass;
  sim-lane gotcha memoed (machine_cleanup wipes runtimes AND devices).
- 2026-07-01 Glenn's SaneClip ideas (branch `feature/floating-resizable-history-glenn`,
  NOT committed, NOT released; bumped to 2.3.12/2312). Implemented all four
  customer requests from email #983 plus the squashed-footer bug he screenshotted:
  1. Resizable floating window — `showHistoryWindow()` panel now uses
     `.resizable` styleMask + `contentMinSize`/`contentMaxSize`
     (`ClipboardHistoryView.windowMin/Max` = 300×360 … 760×1400); root view
     stretches with `maxWidth/maxHeight: .infinity`.
  2. New setting `SettingsModel.useFloatingHistoryWindow` (toggle in
     ShortcutsSettingsView). `showHistoryPopover()` routes to the floating
     window when on. (Did NOT add the menu-bar toggle-close branch in
     `togglePopover` because SaneClipApp.swift is already >800 lines and the
     size gate blocks edits; window closes via its close button / Cmd-W / the
     dedicated `toggleHistoryWindow()` shortcut.)
  3. Remembers position — `setFrameAutosaveName(historyWindowFrameAutosaveName)`
     + `ensureWindowOnScreen()` re-center guard for lost displays.
  4. Drag-out — `.onDrag { dragItemProvider() }` on `ClipboardItemRow`
     (text→NSString, image→NSImage).
  Footer squash fix: extracted `HistoryFooterView` (status cluster in a
  horizontal ScrollView, Settings/Smart Clear pinned) + `HistoryPasteStackPanel`
  to get `ClipboardHistoryView` back under the 800-line owner limit.
  Verify: build clean, 178 tests pass (Mini; encryption test SecurityTests.swift:397
  "SyncDataModel marks encrypted CloudKit records" is FLAKY — failed once, passed
  on re-run, unrelated to this change — pre-existing).

  ADVERSARIAL REVIEW (16-agent workflow) found + FIXED 6 real bugs, rejected 2
  false alarms (NSImage IS NSItemProviderWriting on macOS 13+; fullSizeContentView
  title overlap doesn't occur):
  - [HIGH, FIXED] Paste from floating window failed — `handleDismissForPaste` only
    closed the popover; synthetic Cmd+V landed on our panel. Now moved to
    +HistoryWindow.swift and, when the window is visible, does
    `historyWindow.orderOut(nil); NSApp.hide(nil)` so focus returns to the target
    app before the paste. `handleReopenHistoryAfterPaste` routes to the window.
  - [HIGH, FIXED] `.onDrag` on pinned rows broke pinned `.onMove` reorder. Gated to
    non-pinned rows via `.onDragOut(enabled: !isPinned)`.
  - [MED, FIXED] Footer scroll hid Merge/Paste/Stack with no affordance. Item count
    now pinned outside the scroll; only secondary controls scroll, `showsIndicators: true`.
  - [MED, FIXED] `ensureWindowOnScreen` only recovered fully-off-screen frames.
    Now clamps origin into `visibleFrame`.
  - [MED, FIXED] Menu-bar 2nd click didn't close floating window — added close
    branch to `togglePopover`.
  - [MED, NOT FIXED — pre-existing/by-design] hotkey opens the window regardless of
    setting: the floating window predates this change; the hotkey always opened it.
    Changing it would remove existing behavior. Left as-is.

  VISUAL AUDIT: rendered the real ClipboardHistoryView on the Mini via window-server
  capture (CGWindowListCreateImage — shows true title bar + correct ScrollView
  content; cacheDisplay mis-captures horizontal scroll views) across a
  failure-mode matrix (customer sizes/aspect ratios: 300x360 min … 720x430 wide;
  free/pro, empty, long text, filters-open, merge-active, stack-open). Receipt +
  PNGs: `outputs/visual-audit-glenn-20260701/`. Footer squash CONFIRMED FIXED at
  all widths. NEW PRE-EXISTING FINDING (not in scope): the filter picker row
  (`if showFilters` in ClipboardHistoryView) uses fixed-width pickers (~440pt) that
  overflow/clip at the 320pt popover — mitigated by the resizable window; worth a
  follow-up (wrap in ScrollView or flexible widths).

  PENDING: live-app resize/drag interaction still not driven on-device (static
  window-server renders only); commit + release decision (owner); reply to
  email #983 drafted, awaiting owner approval to send.

- 2026-07-01 (cont.) KILLER UPDATE shipped on same branch (commits 2d811e9 →
  ce023e3 → 6ba9e9c; NOT pushed/merged; still 2.3.12). Ran a 7-analyst UX audit
  workflow (71 findings → ranked roadmap), implemented the low-risk high-impact
  set: ScrollViewReader auto-scroll of the selection; Home/End/PageUp/PageDown;
  `P` to pin selected; `Esc` clears search→filters→closes floating window; moved
  the floating-window toggle to General→Appearance (discoverability); filter row
  extracted to HistoryFilterBar with horizontal scroll (fixes the 320pt clip);
  drag-out grip affordance on hover; relaxed row metadata clamp; honest ⌘⌃N
  hints (only shown when accurate). Key handlers live in
  HistoryListKeyboardShortcuts (ViewModifier) — needed to keep the SwiftUI body
  under the type-check budget (a long inline .onKeyPress chain timed out). A
  second adversarial review caught + FIXED: (a) P-pin lost the selection (now
  re-anchors selectedIndex by id), (b) collection badge could wrap (re-added
  .lineLimit(1)). 179 tests pass on Mini; matrix re-rendered + inspected.
  DEFERRED (needs live focus testing, not shipped): type-ahead catch-all (j/k
  conflict) + auto-focus-search. PROPOSE-TO-OWNER bigger bets from the audit:
  always-on-top pin, drag-IN capture, content-aware quick actions, multi-select
  batch, per-display frame memory.

- 2026-07-01 Mini Dock "3 SaneClip icons" report — diagnosed as ghost runtime
  Dock tiles from dev build/test/kill cycles (+ ~94 stale LaunchServices records
  for deleted paths); only 2 real bundles on disk (/Applications + 1 DerivedData),
  NOT pinned, NOT a duplicate install, NOT a shipping-app bug. Cleared with
  `killall Dock` on the Mini. `lsregister -kill` is removed in current macOS.
  See memory [[saneclip-mini-dock-ghost-icons]]. Proposed prevention (owner):
  graceful quit + `killall Dock` in the Mini test/cleanup flow (SaneProcess).

- 2026-06-27 keychain prompt-storm audit — SaneClip is NOT affected (no code
  change needed). The "wants to use your confidential information" prompt storm
  that hit the non-sandboxed apps (SaneHosts/SaneSync/SaneClick) comes from the
  legacy login keychain's per-item ACL being bound to the build signature.
  SaneClip's customer builds — direct `Release`, `Release-AppStore`,
  `Release-Setapp` — are ALL sandboxed (`app-sandbox=true`), so their keychain
  items already live in the data-protection keychain and are governed by the
  app-identifier entitlement, not signature ACLs. (`SaneClipDist.entitlements`
  is a dead/unused file — no config references it.) Confirmed by the passing
  test "Startup keychain reads do not trigger authentication UI". Only action
  taken: aligned the SaneUI pin to `f8e5274` for fleet consistency (commit
  `96631f7`, supersedes the earlier uncommitted 0133bad→83d8259 bump; no
  behavior change, no access group passed). Mini verify: 172 tests pass.

- 2026-06-13 validation refresh note:
  - Cross-app SaneProcess validation still marks SaneClip customer UI/project
    QA proof stale; refresh with `./scripts/SaneMaster.rb customer_ui_sweep
    --json`, then `./scripts/SaneMaster.rb customer_ui_contract --json
    --strict-visual --no-exit` on the Mini before treating the current release
    state as fresh.
  - The private-key detector fixture now avoids embedding literal PEM header
    blocks while still exercising the detector path.

- Current released version: `2.3.9` / build `2309`.
- Direct Mac channel `2.3.9` is live on R2, Sparkle appcast, website,
  Homebrew, GitHub release, and email webhook. Verified live URL:
  `https://dist.saneclip.com/updates/SaneClip-2.3.9.zip`.
- App Store `2.3.9` is submitted for both platforms as of
  2026-06-06 17:07 EDT:
  `macos: 2.3.9 (WAITING_FOR_REVIEW) | ios: 2.3.9 (WAITING_FOR_REVIEW)`.
- Setapp `2.3.9` build `2309` is `Released` as of 2026-06-18
  `15:22:39Z`, with `action_required: false` and no reviewer comment. The
  current hosted archive
  `https://store.setapp.com/app/1847/46886/app-1781722157-6a32ec2d05294.zip`
  passes the final strict SaneProcess Setapp validator: 1024x1024 root PNG,
  visible pixels `x=100...923,y=100...923`, rounded 824px frame mask, rendered
  bundle `AppIcon.icns` geometry, universal executable, valid signatures, and
  restricted-entitlement profile coverage including iCloud services.
- SaneClip listing media synced from dedicated `docs/images/setapp/` assets
  through `setapp_media_sync --app SaneClip` on 2026-06-18; the portal verified
  screenshot IDs `11967...11971` in order and direct `store.setapp.com` images
  byte-match the local PNGs. The current gallery now leads with actual
  clipboard history and menu-capture workflows, then Touch ID/privacy settings,
  snippets, and private storage. Public `https://setapp.com/apps/saneclip`
  still renders older `177741...` screenshot URLs as of `2026-06-18T15:22Z`, so
  re-check public propagation before claiming the Setapp page visually fixed.
- Historical Setapp `2.3.9` build `2309` was **Needs Revision** as of
  2026-06-15 email #874. Setapp's reviewer could not open the app; the linked
  CleanShot shows
  the normal internet-download warning followed by
  `The application "SaneClip.app" can't be opened.` The archive involved was:
  `~/SaneApps/outputs/setapp_review/20260615T133009Z-saneclip-2.3.9-setapp/SaneClip-Setapp-2.3.9.zip`;
  SHA256
  `84891bb4e3099ee6825db8f973d0558a39c7942b54abc88b6056edfe73055586`;
  portal archive URL:
  `https://store.setapp.com/app/1847/46886/app-1781530411-6a2fff2b7d19b.zip`.
  Local reproduction on the Mini from the Setapp-hosted ZIP showed both
  quarantined and clean copies failing `open -n` with RBS/launchd POSIX error
  `163`, and direct execution exiting `137`.
- Root cause for email #874: `setapp_package` archived with
  `CODE_SIGNING_ALLOWED=NO` and then manually signed, but did not copy
  `Contents/embedded.provisionprofile` into the app/extension before signing.
  The app signed iCloud/app-group entitlements and static checks still passed
  (`codesign`, notarization, stapler, `spctl`, universal slices), but
  LaunchServices killed the app before it opened. The correct installed main
  profile is `SaneClip Setapp Developer ID 2309`, UUID
  `92dd39d1-a8d0-4833-a281-1648679d7240`, and it covers
  `iCloud.com.saneclip.app`.
- Active remediation in progress: shared SaneProcess `setapp_package` now
  embeds matching provisioning profiles before signing and runs a quarantined
  LaunchServices open proof from the final ZIP; `setapp_upload --validate-only`
  now rejects signed restricted-entitlement bundles that are missing
  `Contents/embedded.provisionprofile` or whose embedded profile does not cover
  the signed bundle/iCloud containers. Regression proof: Mini
  `ruby scripts/setapp_upload_test.rb` passed `9/9`, and the bad Setapp-hosted
  ZIP now fails validation with
  `Setapp archive app signs restricted entitlements but is missing Contents/embedded.provisionprofile`.
- Verified replacement package built on the Mini:
  `~/SaneApps/outputs/setapp_review/20260615T230825Z-saneclip-2.3.9-setapp/SaneClip-Setapp-2.3.9.zip`;
  SHA256
  `e3e223edeb8eab39345d8c0dcc59debf3ce5240ac8aa5720fb020e6390f56e09`.
  It embeds main profile `SaneClip Setapp Developer ID 2309`
  (`92dd39d1-a8d0-4833-a281-1648679d7240`) and widget profile
  `SaneClip Setapp Widgets Developer ID`
  (`9f11d50b-2f49-42d0-9dc2-04e448a39534`). Notarization accepted with
  submission ID `2c886f25-33e3-4067-8814-95cc3e2bd31c`; stapler validation,
  `spctl`, `setapp_upload --validate-only`, and manual quarantined open proof
  passed. Manual proof log showed `open_status=0` and a translocated SaneClip
  process `94955` from the final ZIP, then the probe process was terminated.
- The verified replacement archive was attached to Setapp app `1847`, version
  `46886`, and the Mini Safari portal `Submit for review` button was clicked.
  `./scripts/SaneMaster.rb setapp_status --app SaneClip:1847:46886` now reports
  `In Review (status 5)` with no action required. New Setapp archive URL:
  `https://store.setapp.com/app/1847/46886/app-1781565277-6a30875d9c3fb.zip`.
- 2026-06-16 verification refresh:
  - Mini `./scripts/SaneMaster.rb verify --timeout 900` passed `172` tests in
    `34s`, including the Setapp universal-architecture regression test.
  - Mini `./scripts/SaneMaster.rb setapp_status --app SaneClip:1847:46886 --json`
    confirmed Setapp status `In Review`, `action_required: false`, with live
    archive URL
    `https://store.setapp.com/app/1847/46886/app-1781565277-6a30875d9c3fb.zip`.
  - The exact live Setapp-hosted archive downloaded from that URL has SHA256
    `e3e223edeb8eab39345d8c0dcc59debf3ce5240ac8aa5720fb020e6390f56e09` and
    passed the hardened Mini validator:
    `ruby ~/SaneApps/infra/SaneProcess/scripts/setapp_upload.rb --validate-only`.
- Release commits pushed: `b412aa6` (2.3.9 fixes), `8d8f1c5` (version tag
  `v2.3.9`), `6a9e206` (site links), `52d8a22` (release metadata).
- GitHub issue `sane-apps/SaneClip#14` was commented and closed as shipped in
  `2.3.9` on 2026-06-06.
- Full release verification on 2026-06-06 passed:
  `./scripts/SaneMaster.rb verify` green with `166` tests, customer UI sweep
  passed, `release_preflight` passed with warnings only, `appstore_preflight`
  passed with zero issues, direct ZIP HTTP 200, appcast propagation verified,
  Homebrew cask verified, email webhook verified, and strict post-release
  checks passed.
- Lemon Squeezy hosted paid files are in sync as of 2026-06-06 17:57 EDT.
  Dashboard uploads were updated for SaneBar `2.1.66`, SaneClip `2.3.9`, and
  SaneHosts `1.1.16`; the live hosted-file tracker reports `Current actions: 0`
  and the local upload folder reports `stale: 0`, `missing latest: 0`,
  `unexpected: 0`. Evidence:
  `outputs/hosted_file_actions_20260606_synced.md`.
- 2026-06-06 GitHub `#14` / menu-bar visibility fix:
  - Added a Mac setting in General > Appearance: `Show menu bar icon`.
  - The menu bar item visibility updates live via `statusItem.isVisible`; hiding
    it closes any open popover.
  - Entry-point invariant is enforced both ways: hiding the menu bar icon forces
    Dock visibility on, and hiding Dock while the menu bar icon is hidden forces
    the menu bar icon back on.
  - Launch recovery now repairs a bad persisted state where both are false by
    restoring Dock visibility and writing `showInDock=true` back to defaults.
  - Verification: `./scripts/SaneMaster.rb verify` passed with `164` tests on
    2026-06-06 after the invariant fix.
  - Visual verification: screenshot-enabled `./scripts/SaneMaster.rb verify`
    passed with `164` tests using the test harness hint file, producing
    `outputs/visual-qa-20260606-menu-dock/settings-general-render.png`.
    Inspected render: the new toggle is readable, aligned, and well placed in
    Appearance above the menu bar icon picker with no visible overlap/clipping.
  - Customer UI QA was refreshed after the settings change:
    `ruby scripts/customer_ui_action_sweep.rb --json` passed with transcript
    `outputs/customer-ui/sweep-20260606T195918Z/customer-action-runtime.log`.
  - `./scripts/SaneMaster.rb release_preflight` passed after the refreshed UI
    receipt with warnings only: 12 uncommitted files, UserDefaults/migration
    change warning, appcast/Homebrew still live at `2.3.8` before publish, 1
    open GitHub issue, and 6 pending emails.
- 2026-06-06 Setapp review remediation:
  - Support triage found Setapp/MacPaw email #816 was not a resolvable duplicate;
    it needs a substantive security-response reply before #798/#799/#800 can be
    cleaned up as related no-reply Setapp notifications.
  - SaneClip Setapp entitlement cleanup is applied for local `2.3.9` build
    `2309`:
    removed the unnecessary Apple Events entitlement and old Sparkle
    `$(PRODUCT_BUNDLE_IDENTIFIER)-spki` / `-spks` mach-lookup placeholders from
    `SaneClip/SaneClipSetapp.entitlements`, leaving only
    `com.setapp.ProvisioningService`.
  - Setapp build script now deletes the unused
    `NSAppleEventsUsageDescription` from the built Info.plist while continuing
    to strip Sparkle framework/direct-store update keys.
  - Setapp provisioning was fixed on 2026-06-06 by enabling CloudKit/iCloud
    container `iCloud.com.saneclip.app` on bundle ID
    `com.saneclip.app-setapp` in Apple Developer, regenerating Developer ID
    profile `SaneClip Setapp Developer ID 2309`, and installing it on the Mini.
  - Setapp archive validation passed: deep signature valid, CloudKit/app-group
    entitlements present, `setappPublicKey.pem` bundled, 1024/512 icon
    representations present, forbidden App Store/Sparkle keys stripped, and
    Sparkle remains weak-linked only.
  - Setapp upload succeeded through portal fallback because the official CI
    upload token is not configured. Archive is attached to app `1847`, version
    `46886`, for review.
  - Draft security response for email #816 was updated to mention SaneClip
    `2.3.9` build `2309` and passed `reconcile`/`verify-facts`; do not send
    until the final release/submission status is accurate and explicit approval
    is recorded with `check-inbox.sh approve`.
- 2026-06-15 Setapp rejection remediation, superseded by email #874:
  - Email #869 / reviewer note said the app could not be opened. The submitted
    Setapp ZIP was signed/notarized but the main app executable and plist
    advertised only `arm64`; the widget extension was already universal.
  - Fixed Setapp build settings so the app and widget build `x86_64 arm64`, and
    added `MPSupportedArchitectures = [arm64, x86_64]` to the Setapp plist patch.
  - Added test coverage in `Tests/SaneClipTests.swift` for the universal Setapp
    settings, and expanded `setapp_upload.rb --validate-only` to reject archives
    that are missing Intel or Apple-silicon slices in the app/extension binaries
    or plist metadata.
  - Added SaneMaster `setapp_package`, which xcodegen-builds the Setapp archive,
    signs, notarizes, staples, zips, and runs the Setapp archive validator.
  - Mini verification passed at that time: `ruby scripts/setapp_upload_test.rb` `7/7`,
    `./scripts/SaneMaster.rb verify --timeout 900` `172` tests, package build
    notarized accepted, Gatekeeper accepted, and `setapp_upload --validate-only`
    passed for the final ZIP.
  - Later email #874 proved this validation was incomplete: the rebuilt package
    still failed LaunchServices because the matching provisioning profile was
    not embedded. Do not treat the old `7/7` validator result as enough Setapp
    release proof.
  - Setapp portal fallback attached the fixed archive, Safari confirmed
    "Your app is in review!", and `./scripts/SaneMaster.rb setapp_status --app
    SaneClip:1847:46886` reports `In Review (status 5)` with no action required.
- 2026-06-06 iOS publish fix:
  - First `2.3.8` release run submitted macOS successfully, then iOS archive
    failed because shared `SyncCoordinator.swift` referenced macOS-only
    `SettingsModel.shared.encryptHistory`.
  - Fixed by moving sync encryption decision to the shared `encryptHistory`
    UserDefaults key via `SyncCoordinator.encryptHistoryKey` and adding source
    regression guards.
  - Verification passed after the fix: `./scripts/SaneMaster.rb verify` green
    with `160` tests; fresh customer UI sweep passed with receipt timestamp
    `2026-06-06T19:19:48Z`.
  - Retried the iOS-only App Store lane: archive succeeded, IPA export
    succeeded, build `2308` processed successfully, screenshots/metadata/IAP
    passed, and iOS version `2.3.8` reached `WAITING_FOR_REVIEW`.
- 2026-06-06 Lemon Squeezy hosted-file cleanup:
  - Updated SaneBar, SaneClip, and SaneHosts paid hosted files in the Lemon
    Squeezy dashboard using the saved Mini Safari login.
  - Verified via `./scripts/SaneMaster.rb hosted_file_actions --json-out
    outputs/hosted_file_actions_20260606_synced.json --evidence-out
    outputs/hosted_file_actions_20260606_synced.md`.
  - Final result: `Current actions: 0`; all five direct-download apps in the
    tracker are `In sync`.
- 2026-06-06 best-in-class audit / `2.3.8` staging:
  - Market/platform research was refreshed in `.claude/research.md`. Conclusion:
    SaneClip should be positioned as Mac-first automatic capture plus
    iPhone/iPad companion flows. Do not promise impossible iOS background
    clipboard-history parity.
  - Parallel audit lanes covered website/docs, signing/privacy, support,
    tooling, and runtime resources. Fixed confirmed blockers: homepage
    webhook/web-integration overclaim, contradictory "no telemetry" public
    copy, Mac-only support FAQ for iPhone users, iOS CloudKit upload encryption
    hard-coded plaintext path, and share-extension image activation metadata.
  - `project.yml`/`SaneClip.xcodeproj` now declare
    `NSExtensionActivationSupportsImageWithMaxCount: 1` for the iOS share
    extension.
  - Sync upload tests now guard that iOS CloudKit records do not hard-code
    `encrypt: false`; `SyncDataModel` encrypted CloudKit record round-trip is
    covered by tests.
  - Verification passed after the version bump:
    `./scripts/SaneMaster.rb verify` green with `160` tests.
  - Customer UI QA refreshed after the version bump:
    `ruby scripts/customer_ui_action_sweep.rb --json` passed with transcript
    `outputs/customer-ui/sweep-20260606T184145Z/customer-action-runtime.log`;
    `./scripts/SaneMaster.rb customer_ui_contract --json --no-exit` passed with
    receipt timestamp `2026-06-06T18:41:45Z`.
  - `./scripts/SaneMaster.rb release_preflight` passed with warnings only:
    30 uncommitted files, appcast/Homebrew still at live `2.3.7` before publish,
    1 open enhancement issue, and 6 pending emails.
  - `./scripts/SaneMaster.rb appstore_preflight` passed with warning only:
    30 uncommitted files. ASC version lanes are clear:
    `macos: 2.3.8 clear | ios: 2.3.8 clear`.
  - Historical release blocker resolved on 2026-06-06: Lemon Squeezy hosted
    paid files were updated after the `2.3.9` release; see the current-state
    evidence entry above.
- 2026-06-06 post-audit remediation pass:
  - iPhone/iPad is now consistently framed as a companion, not Mac feature
    parity. Onboarding, empty states, website guides, README, Fastlane metadata,
    and release notes were updated around current-pasteboard limits, Share
    sheet import, foreground sync, and Mac-as-full-app boundaries.
  - The iOS History pending clipboard affordance is visible again and now has
    explicit save/dismiss actions. Visual verification passed on iPhone 17 Pro
    simulator for onboarding, History pending-card placement, and Settings Help.
  - Normal iOS users no longer receive demo history; demo data is restricted to
    screenshot mode.
  - Settings now exposes Support and Report a Bug, and the old explanatory
    Settings footer was removed after visual verification showed tab-bar
    overlap.
  - Privacy/security boundaries were tightened: Shortcuts/App Intents respect
    Touch ID history lock, widget previews are cleared while history lock is
    enabled, image assets are encrypted when history encryption is enabled, and
    iOS import/share paths skip high-risk sensitive text while allowing ordinary
    email/contact text.
  - Data-loss fixes: history export/import now round-trips through
    `SavedClipboardItem` with legacy export fallback; Paste Stack consumes only
    after pasteboard write succeeds; URL scheme copy no longer leaves
    self-write suppression stuck at `Int.max`; local edit/delete paths now queue
    supported sync updates/deletes, including iOS companion delete.
  - Share Extension waits for async item loads before completing and supports
    text, URL, and image saves through the shared app-group history container.
  - Public webhook claims were narrowed because webhook delivery is not exposed
    in Settings/runtime; public docs now advertise supported URL schemes,
    App Intents, and Shortcuts only.
  - QA receipt semantics corrected for sync/iOS external boundaries; refreshed
    customer UI receipt timestamp `2026-06-06T17:43:03Z`; contract passed with
    no issues.
  - Verification passed: `./scripts/SaneMaster.rb verify` green with `158`
    tests; iOS simulator `SaneClipIOS` build/run passed on iPhone 17 Pro
    (iOS 26.5). Remaining verify warnings are pre-existing:
    `Core/ClipboardManager.swift` parameter count and `Core/Sync/SyncCoordinator.swift`
    file length.
  - Historical external action resolved on 2026-06-06: Lemon Squeezy hosted
    files were updated and now pass the hosted-file tracker.
- 2026-06-04 `2.3.7` release-candidate proof:
  - iPhone/iPad companion foreground sync now starts from `ContentView` on
    launch/scene activation, refreshes every 8 seconds while foregrounded, and
    suppresses the local pasteboard save banner when iCloud sync is enabled so
    Mac-origin clips do not look like they require extra manual acceptance.
  - App Store and direct-release notes were updated for the foreground sync
    behavior; `project.yml` and regenerated `SaneClip.xcodeproj` are bumped to
    `2.3.7` / build `2307`.
  - Follow-up refactor pass moved menu/context-menu construction into
    `SaneClipAppDelegate+Menus.swift`; `SaneClipApp.swift` is now under the hard
    800-line split threshold. `GeneralSettingsView.swift` remains slightly over
    the 500-line attention threshold at 544 lines and should be split further in
    a later cleanup.
  - Mini `./scripts/SaneMaster.rb verify --timeout 900` passed with `150` tests.
  - Mini `./scripts/SaneMaster.rb customer_ui_sweep --json` passed with 12
    actions and receipt timestamp `2026-06-04T03:27:08Z` after updating the
    sweep source guards for the new split files.
- 2026-06-04 `2.3.7` final release/submission proof:
  - Direct release completed: notarized/stapled Mac zip
    `SaneClip-2.3.7.zip`, SHA-256
    `402ce8addf15b0396c9a158c537f521447c69118d955f6d5c8e4f4f56ba96892`,
    Sparkle signature
    `150eUUtx4gXWD6ozCH3QCuF3KSGZTNZ39niL+lsQF1KFLOBbQjAeDX9LNQJM18iQ41D+N6TH0ZW4OhaD6QFoAw==`.
  - Live direct URL verified `HTTP 200`:
    `https://dist.saneclip.com/updates/SaneClip-2.3.7.zip`, content length
    `3825199`.
  - Live appcast verified `2.3.7` with `sparkle:version="2307"`.
  - Homebrew tap updated to `2.3.7`.
  - Email webhook Worker updated/deployed for SaneClip bundle/download
    delivery; webhook tests passed `23/23`.
  - Final Mini verify passed `154` tests.
  - Final Mini customer UI sweep passed `12` actions with receipt timestamp
    `2026-06-04T04:24:52Z`.
  - Final `appstore_preflight` passed: `ALL CLEAR — ready for App Store
    submission`.
  - macOS App Store build `2307` uploaded, processed, attached to ASC version
    `2.3.7`, and submitted. ASC state:
    `platform=MAC_OS version=2.3.7 state=WAITING_FOR_REVIEW`,
    submission ID `f4f13e05-09bd-4e13-a776-4a814802dac9`.
  - iOS App Store build `2307` uploaded, processed, attached to ASC version
    `2.3.7`, and submitted. ASC state:
    `platform=IOS version=2.3.7 state=WAITING_FOR_REVIEW`,
    submission ID `e2b88dbd-3177-466b-beab-527367c3e6ee`.
  - IAP price schedule was accidentally created at `$6.99` by the helper
    default during the first macOS submit attempt, then immediately corrected
    with `--iap-price-usd 14.99`; both macOS submit-only and iOS submit
    verified USA `$14.99`.
  - Final `release_preflight` passed with warnings only: 1 open GitHub issue,
    3 pending customer emails, and night-release timing.
- 2026-06-04 settings/window refactor proof pass:
  - Split settings/window ownership without changing behavior:
    `SaneClipAppDelegate+HistoryWindow.swift` now owns history window/popover
    presentation, `SettingsWindowController.swift` owns the settings window, and
    `SettingsView.swift` was split into focused settings files for General,
    General actions, Excluded Apps, Shortcuts, and Clipboard Rules.
  - Added `SaneClipAppDelegate+HistoryWindow.swift` to both macOS app targets in
    `project.yml` and regenerated `SaneClip.xcodeproj` with XcodeGen.
  - Updated source-policy tests so popover anchoring and launcher/reopen history
    behavior read the extracted history-window file.
  - Mini verification passed after the split:
    `./scripts/SaneMaster.rb verify --timeout 900` passed `149` tests. A second
    screenshot-enabled verify using `/tmp/saneclip_screenshot_dir.txt` also
    passed `149` tests and rendered settings screenshots.
  - Mini runtime visual smoke passed:
    `outputs/visual-audit-20260604/visual_smoke_20260603-220115_80465/receipt.json`.
    SaneClip had no normal app window, so `app-see` was skipped by design for
    the menu-bar launch.
  - Clean rendered visual evidence copied locally under
    `outputs/visual-audit-20260604/rendered-settings/`; inspected
    `settings-general-render.png`, `settings-shortcuts-render.png`,
    `settings-license-render.png`, and `history-smart-clear-render.png`.
    The inspected renders had readable bright text and no visible overlap or
    clipping.
  - Fresh research cache entry added for the XcodeGen/root-source and
    cross-file access findings:
    `.claude/research.md` section `SaneClip Settings/Window Refactor Source Inclusion`.
- 2026-05-27 09:35 EDT cross-product launch ops reran canonical Mini
  `launch_readiness`; it exited `1`, so no launch, directory, or public-reply
  action was executed. The active blockers are still the `needs_dmca` piracy
  page, App Store/iOS conversion surfaces needing a fresh check, the
  local-only 30-second video, Mini `release_preflight` carrying `4` warnings,
  and the shared validation report marking SaneClip customer UI proof stale and
  older than 12 hours. The same-day `2026-05-27 10:00 EDT` Clipboard/OCR
  decision slot had not opened yet at decision time, so it stayed pending
  rather than being marked complete early. No new public URL was created in
  this run.
  2026-06-16 correction: GitHub issues `#9-#12` were rechecked with
  `gh issue view` and are already closed as of 2026-05-18, so they are not
  current launch blockers.
- 2026-05-24 23:21 EDT webhook drift cleanup: sane-email-automation
  `PRODUCT_CONFIG` was updated and deployed so live SaneClip order/download
  emails now serve `SaneClip-2.3.6.zip`; live signed download snapshot verified
  file/version/domain and SaneClip `release_preflight` passed with warnings
  only.
- SaneClip `2.3.7` direct channels are live: R2/appcast/site/Homebrew/email
  Worker were synced during the release run.
- Mac App Store and iOS App Store `2.3.7` are both `WAITING_FOR_REVIEW`.
- Local and Mini repos were clean after submission checks.
- Open customer/public follow-up: GitHub `#13` should receive a user-approved
  reply saying 2.3.6 improves Protect Passwords for generated passwords copied
  from browser extensions.

## Release/Process Findings

- The stale ASC macOS `2.3.4` lane was still `WAITING_FOR_REVIEW`. It was
  withdrawn, became `DEVELOPER_REJECTED`, then repaired/retargeted to `2.3.6`
  before upload.
- SaneProcess was fixed so full release version-state checks call
  `appstore_submit.rb --repair-version-state --preflight-version-state`; test
  coverage now asserts repair runs before preflight.
- SaneProcess routed scratch cleanup and `.sanemaster/` ignore handling were
  fixed so routed release workspaces do not leave untracked scratch blockers.
- SaneClip App Store metadata was updated with explicit copyright,
  content-rights, export-compliance, and iOS accessibility declaration families.
- The strict customer UI receipt was refreshed on the Mini and now includes
  screenshot evidence for `snippets-management-actions`.
- SaneProcess routed release reconcile was fixed in
  `~/SaneApps/infra/SaneProcess` commit `cb934c4` so Air-origin releases trust
  the routed Mini workspace context instead of trying to reverse-SSH to
  `Stephans-MacBook-Air.local`.
- App Store archive/export from SSH hit `errSecInternalComponent` for widget
  codesign. Working path was: unlock/grant keychain partition access once, then
  run short archive/export scripts through `mini-gui-run.sh` so Xcode signs in
  the Mini GUI session. Avoid long inline `mini-gui-run.sh` commands; use a
  generated `build/*.sh` script to prevent Terminal command-injection stalls.
- The first macOS App Store archive made with `CODE_SIGN_STYLE=Automatic` and
  blank `CODE_SIGN_IDENTITY` dropped sandbox entitlements. Correct archive path
  is the normal `SaneClip-AppStore` scheme with `Release-AppStore`,
  `-destination generic/platform=macOS`, and the project-configured
  entitlements. Verify both app and widget package payloads contain
  `com.apple.security.app-sandbox` before upload.
- Apple returned transient `500` errors while reserving macOS screenshot upload
  slots during the first submit. A separate `--screenshots-only` retry succeeded
  before the submit-only run.

## Verification Receipts

- 2026-06-06 iPhone pending clipboard import fix: History now shows a visible
  pending clipboard save card in both empty and populated states when iOS
  reports new local pasteboard content. The save action imports every current
  `UIPasteboard.items` payload item it can read, dedupes text/images, clears
  pending state after user action, and suppresses self-write pending prompts
  after copying an existing clip. Documented the iOS limitation that separate
  overwritten copy operations cannot be reconstructed once SaneClip reactivates;
  only the latest/current pasteboard payload can be saved. Visual QA captured
  the forced DEBUG pending-card state at
  `outputs/visual-qa-20260606/iphone-pending-clipboard-card.jpg` and verified
  text fit, placement below the context banner/search area, and no overlap with
  the list or tab bar. Verification: `./scripts/SaneMaster.rb verify --timeout
  900` passed with 154 tests on 2026-06-06 after regenerating
  `SaneClip.xcodeproj`.
- 2026-06-03 iPhone no-extra-tap sync fix: the iOS companion now starts
  CloudKit foreground sync from `ContentView` on launch/scene activation,
  keeps an 8-second foreground refresh loop in `ClipboardHistoryViewModel`,
  and suppresses the local iPhone pasteboard banner while iCloud sync is
  enabled so Mac-origin clips do not look like they require pasteboard
  permission/acceptance. Mini `./scripts/SaneMaster.rb verify --timeout 900`
  passed with 150 tests, including `iPhone sync refreshes automatically while
  foregrounded`. Research cache entry added:
  `.claude/research.md` section
  `SaneClip iPhone Foreground Sync / Pasteboard Banner`.
- 2026-05-24 Basic/Pro visual recheck: Mini Basic visual smoke
  `visual_smoke_20260524-190622_22006` and Pro visual smoke
  `visual_smoke_20260524-190813_30579` were inspected. Basic correctly showed
  locked Pro actions; Pro showed unlocked Paste/Stack/Smart Clear actions.
  Mini `customer_ui_sweep --json` generated receipt
  `2026-05-24T23:10:09Z`, and strict customer UI contract passed with no
  issues or warnings.
- 2026-05-24 SaneClip `#14` reopen/launcher patch: `SaneClipAppDelegate.applicationShouldHandleReopen` now opens/brings forward the history window when the already-running app is relaunched by Alfred/Launch Services. Mini `./scripts/SaneMaster.rb verify --timeout 900` passed with `155` counted tests, including `Reopening the running app opens the history window`. The separate request to hide the menu bar item remains an enhancement and is not part of this narrow patch.
- Mini verify passed 154 tests during:
  - SaneClip password-protection fix pre-push.
  - App Store metadata/visual receipt fix pre-push.
  - Duplicate changelog cleanup pre-push.
  - The final release rerun before App Store package export.
- `customer_ui_sweep --json` passed in the routed workspace at
  `2026-05-21T19:54:33Z`.
- `appstore_preflight` passed in the routed workspace with one warning only:
  the generated customer UI receipt was locally dirty after the sweep.
- App Store package export passed, package preflight passed, uploads completed,
  build `2307` processed on both macOS and iOS, screenshots uploaded, metadata
  synced, IAP readiness passed at `$14.99`, and ASC returned
  `Successfully submitted for review` for both platforms.
- Lemon Squeezy hosted-file audit at `2026-05-21T20:03:24Z` returned
  `current_actions: []`; SaneBar, SaneClick, SaneClip, SaneHosts, and SaneSales
  all show `In sync`.

## Next

1. Show exact customer/GitHub reply drafts and wait for approval before posting.
2. Check GitHub/App Store status later; SaneClip macOS and iOS `2.3.7` are both
   submitted but not yet approved.
3. Leave `.outreach.yml` alone unless the user explicitly asks to handle launch
   calendar/outreach changes.

## Launch Ops - 2026-06-23

- Cross-product launch ops reran canonical Mini `./scripts/SaneMaster.rb launch_readiness --json` from the SaneClip repo. It stayed red.
- Launch remains blocked by the active DMCA/piracy lane (`needs_dmca`), pending fresh App Store/iOS metadata + conversion-surface checks, local-only launch video status, and stale proof freshness even though `release_preflight` still passes.
- Fresh proof state: `release_preflight` is 19.34 days old with 3 warnings, and the shared validation receipt [`/Users/sj/SaneApps/infra/SaneProcess/outputs/validation/2026-06-23.json`](/Users/sj/SaneApps/infra/SaneProcess/outputs/validation/2026-06-23.json) is still `NOT READY FOR RELEASE` with stale SaneClip customer-UI proof plus missing mini-click/fixture/log artifacts. No launch/directory/scheduling/public-reply action ran today.
