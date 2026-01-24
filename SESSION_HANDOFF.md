# Session Handoff - 2026-01-24

> **Navigation**
> | Bugs | Features | How to Work | Releases | Testimonials |
> |------|----------|-------------|----------|--------------|
> | [BUG_TRACKING.md](BUG_TRACKING.md) | [marketing/feature-requests.md](marketing/feature-requests.md) | [DEVELOPMENT.md](DEVELOPMENT.md) | [CHANGELOG.md](CHANGELOG.md) | [marketing/testimonials.md](marketing/testimonials.md) |

---

## Current Status (2026-01-24)

### Build Status
- **macOS: All 23 tests passing**
- **iOS: Build succeeds, app runs on simulator**

### Completed Phases

| Phase | Version | Features | Commit |
|-------|---------|----------|--------|
| Phase 2 | v1.5 | 9 Power User features | `e1eeb60` |
| Phase 3 | v2.0 | 8 Pro features (security, sync, automation) | `00f805c`, `7b87296` |
| Phase 4 | v3.0 | macOS Widgets, iOS App, iOS Widgets | `64e1cc6`, `70a778f`, `8cc8dd7` |

### Phase 4 Complete

| Feature | Status | Notes |
|---------|--------|-------|
| macOS Widgets | ✅ Complete | Recent Clips, Pinned Clips |
| Shared Data Layer | ✅ Complete | SharedClipboardItem model |
| iOS Companion App | ✅ Complete | History, Pinned, Settings tabs |
| iOS Widgets | ✅ Complete | Recent and Pinned widgets |
| Team Features | ❌ Removed | User rejected (ongoing costs) |

---

## iOS Companion App (Jan 24)

### Files Created
- `iOS/SaneClipIOSApp.swift` - App entry point with TabView
- `iOS/Views/HistoryTab.swift` - History list view
- `iOS/Views/PinnedTab.swift` - Pinned items view
- `iOS/Views/SettingsTab.swift` - Settings with sync status
- `iOS/Views/ClipboardHistoryViewModel.swift` - View model
- `iOS/Views/ClipboardItemCell.swift` - Reusable item cell
- `iOS/Views/EmptyStateView.swift` - Empty state component
- `iOS/Info.plist` - iOS app Info.plist
- `iOS/SaneClipIOS.entitlements` - Release entitlements
- `iOS/SaneClipIOSDebug.entitlements` - Debug entitlements
- `iOSWidgets/SaneClipIOSWidgets.swift` - Widget bundle
- `iOSWidgets/RecentClipsIOSWidget.swift` - Recent clips widget
- `iOSWidgets/PinnedClipsIOSWidget.swift` - Pinned clips widget
- `iOSWidgets/Info.plist` - Widget extension Info.plist
- `iOSWidgets/SaneClipIOSWidgets.entitlements` - Release entitlements
- `iOSWidgets/SaneClipIOSWidgetsDebug.entitlements` - Debug entitlements
- `Shared/Models/SharedClipboardItem.swift` - Cross-platform model

### iOS App Architecture
- **Entry:** `SaneClipIOSApp` with TabView
- **Tabs:** History, Pinned, Settings
- **Data:** Reads from App Group shared container written by macOS app
- **Sync:** Views CloudKit-synced items from Mac

### Bundle IDs

| Target | Debug | Release |
|--------|-------|---------|
| SaneClip | `com.saneclip.dev` | `com.saneclip.app` |
| SaneClipWidgets | `com.saneclip.dev.widgets` | `com.saneclip.app.widgets` |
| SaneClipIOS | `com.saneclip.dev.ios` | `com.saneclip.app.ios` |
| SaneClipIOSWidgets | `com.saneclip.dev.ios.widgets` | `com.saneclip.app.ios.widgets` |

---

## Portal Setup Required

### CloudKit (Phase 3)
- Container: `iCloud.com.saneclip.app`
- Must be created in Apple Developer portal before Release builds

### App Group (Phase 4)
- Group: `group.com.saneclip.app`
- Must be registered in Apple Developer portal for Release builds
- Used by macOS app, macOS widgets, iOS app, iOS widgets

---

## Quick Commands

```bash
# macOS (after XcodeBuildMCP defaults set)
build_macos
test_macos

# iOS (requires iOS 26.2 SDK)
mcp__XcodeBuildMCP__session-set-defaults scheme: SaneClipIOS simulatorName: "iPhone 17 Pro"
build_sim
build_run_sim

# Regenerate project after changes
xcodegen generate
```

---

## Roadmap Status

**Implemented:**
- Phase 2: Extended transforms, snippets, filters, rules, export/import, storage stats
- Phase 3: CloudKit sync, encryption, sensitive data detection, auto-purge, App Intents, URL scheme
- Phase 4: macOS widgets, iOS companion app, iOS widgets

**Not Implementing:**
- Team Features (user rejected - ongoing hosting costs)
