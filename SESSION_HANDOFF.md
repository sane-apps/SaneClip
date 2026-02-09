# Session Handoff - 2026-02-07 (10:10 PM)

## Current State: iOS Visual Polish — Source-Aware Colors

### What Was Done This Session

1. **README + website updated** — Added iOS Companion App section to README.md, feature card to docs/index.html, committed as `254c4d3`
2. **Simulator seeded with realistic data** — Everyday content (messages, recipes, tracking numbers, flight confirmations) replacing technical examples. Marketing peppered in (saneapps.com URL, "Just tried SaneClip..." testimonial)
3. **iOS ClipboardItemCell visual overhaul** — Multiple rounds of user-driven fixes:
   - Fixed gray-on-gray text: explicit `previewColor` (textCloud #e5e5e5 dark, #1A1A1A light) and `metadataColor` (textStone #888888 dark, #555555 light)
   - Font bumped to `.subheadline` weight `.semibold`, metadata to `.caption`
   - Removed all opacity dimming on accent colors
4. **Source-aware color palette** — 9 app-specific colors (Messages=sage, Mail=coral, Safari=sky, Notes=gold, Maps=cyan, Contacts=lavender, Calendar=rose, Photos=amber, Reminders=periwinkle)
   - Split `barColor` (orange for pinned, source for regular) from `accentColor` (always source-aware)
   - Dark mode AND light mode variants (darkened for WCAG AA 4.5:1 on light backgrounds)
5. **Ported to macOS** — `ClipboardItemRow.swift` now has identical source color palette, bar/accent split, colored content type icons
6. **Consistency fixes** — Toast uses `semanticSuccess`, PinnedTab empty state uses `pinnedOrange`, swipe action matches tab tint
7. **3 parallel critic agents** ran: UI/UX critic, color harmony critic, macOS parity explorer

### Commits This Session

| Hash | Description |
|------|-------------|
| `254c4d3` | feat: iOS app overhaul — detail view, Siri Shortcuts, Share Extension |
| `1af0fc1` | feat: source-aware colors for clipboard items on iOS and macOS |

---

## CRITICAL: Outstanding Issue — Maps vs Messages Colors

**User says Maps (#4DBAD4 cyan teal) and Messages (#5EC2A0 sage green) are STILL too similar.** This must be fixed first thing next session. Both are in the green-cyan family.

**Fix approach:** Move Maps to a completely different hue family — try blue (#4B9FE8) or a warmer teal-blue (#3498DB) to create clear visual separation from the green Messages color. The dark AND light variants both need updating.

**Files to edit:**
- `iOS/Views/ClipboardItemCell.swift` — lines ~19-20 (dark) and ~33-34 (light) for maps
- `UI/History/ClipboardItemRow.swift` — matching dark/light maps entries

---

## Color Critic Findings (Not Yet Applied)

From the color harmony critic (partially applied, some remain):
- Pinned orange (#f59e0b) clashes with Notes/Photos warm tones — critic recommends → #d97706
- All source colors should be tested against actual card backgrounds, not just white
- Consider adding a subtle colored background tint to cards from source apps

From the UI/UX critic:
- Settings tab monochrome feels dated compared to colorful History/Pinned tabs
- User already took 3 dark mode screenshots (History, Pinned, Settings) — need 3 light mode + retake dark after color fixes

---

## Simulator Test Data

App Group container with seeded data:
- Path: `/Users/sj/Library/Developer/CoreSimulator/Devices/71BCCECA-4123-48BB-988E-775A2B101515/data/Containers/Shared/AppGroup/C98BAA81-66C4-4872-B8F7-8882BA932E08/widget-data.json`
- Bundle ID (debug): `com.saneclip.dev.ios`
- Simulator: iPhone 17 Pro (`71BCCECA-4123-48BB-988E-775A2B101515`)
- Timestamp format: Apple reference date (Double, seconds since 2001-01-01)

---

## Key Architecture: Source Color System

```
sourceColor (computed per item.sourceAppName)
  ├── colorScheme == .dark → bright/saturated hex
  └── colorScheme == .light → darkened hex (WCAG AA)

barColor = isPinned ? .pinnedOrange : sourceColor
accentColor = sourceColor (always, even on pinned items)
```

Both iOS (`ClipboardItemCell`) and macOS (`ClipboardItemRow`) share identical palettes.

---

## App Store Submission Status

| Field | Value |
|-------|-------|
| App ID | `6758898132` |
| Bundle ID | `com.saneclip.app` |
| State | PREPARE_FOR_SUBMISSION |
| iOS Pricing | Free (companion to $6.99 macOS app) |
| Cross-sell | Aggressive — saneapps.com links in test data |

### Still Needed
- [ ] **Fix Maps/Messages color similarity** (user blocker)
- [ ] Retake all 6 screenshots (3 dark, 3 light) after color fix
- [ ] App Store metadata (description, keywords, category)
- [ ] Privacy policy URL
- [ ] PrivacyInfo.xcprivacy
- [ ] Final TestFlight testing

---

## Build Status

- macOS: BUILD SUCCEEDED, 55 tests pass (6 suites)
- iOS: BUILD SUCCEEDED (SaneClipIOS scheme, iPhone 17 Pro simulator)
- Scheme names: `SaneClip` (macOS), `SaneClipIOS` (iOS)

---

## Gotchas

| Issue | Detail |
|-------|--------|
| Simulator names changed | iPhone 16 Pro → iPhone 17 Pro (OS update) |
| iOS bundle ID (debug) | `com.saneclip.dev.ios` (NOT `com.saneclip.app`) |
| Timestamp encoding | `JSONDecoder()` default = `deferredToDate` = Double, NOT ISO 8601 |
| Sparkle key | ONE key for ALL SaneApps. Public: `7Pl/8cwfb2vm4Dm65AByslkMCScLJ9tbGlwGGx81qYU=` |
| R2 uploads | ALWAYS use `--remote` flag |

---

## Previous Sessions (Archived)
- Feb 7 (earlier): iOS app overhaul — detail view, Siri Shortcuts, Share Extension, App Intents
- Feb 3: SaneClip 1.4 DMG release, Product Hunt launch prep
- Jan 27: Security hardening (7/10 → 9/10), Sparkle conditional compilation
- Jan 26: DMG release readiness, icon fixes
