# Research Cache

Persistent research findings for this project. Limit: 200 lines.
Graduate verified findings to ARCHITECTURE.md or DEVELOPMENT.md.

<!-- Sections added by research agents. Format:
## Topic Name
**Updated:** YYYY-MM-DD | **Status:** verified/stale/partial | **TTL:** 7d/30d/90d
**Source:** tool or URL
- Finding 1
- Finding 2
-->

## iOS Extension Features Research

**Updated:** 2026-02-07 | **Status:** verified | **TTL:** 7d
**Source:** GitHub (Clip, SnipKey), Web Search (Apple Developer, Medium, TechCrunch)

### 1. Custom Keyboard Extension

**Effort Estimate:** 2-4 days for basic implementation, 1-2 weeks for polished version

**Lines of Code:**
- **Minimal implementation:** ~100-150 lines (basic keyboard controller)
- **Production implementation:** ~800-1000 lines total
  - KeyboardViewController: ~220 lines (UIKit lifecycle, data handling, notifications)
  - KeyboardView (SwiftUI): ~650-700 lines (UI, state management, sorting, gestures, biometrics)
  - Info.plist, entitlements, shared framework setup

**Key Files/Targets:**
- New keyboard extension target (separate bundle)
- Shared framework for data access (Core Data/SwiftData)
- App Group entitlement for container sharing
- 3-4 Swift files minimum (controller, view, models, shared utilities)

**Key APIs:**
- `UIInputViewController` (subclass for keyboard lifecycle)
- `UIHostingController` (bridge UIKit to SwiftUI)
- `NotificationCenter` (cross-target communication)
- App Groups for shared container
- `UIPasteboard.general` for clipboard operations
- `LocalAuthentication` if securing content with Face ID/Touch ID

**Complexity Factors:**
- Memory constraints (extensions run with limited RAM)
- Full Access permission controversy (privacy concerns, App Store scrutiny)
- No network access without Full Access (limits cloud sync inside keyboard)
- Gesture handling conflicts (long press, drag, tap on small UI)
- State synchronization between main app and keyboard
- Notification-based architecture creates implicit dependencies
- Background constraints (extensions can be killed aggressively)

**Gotchas & App Store Issues:**
- **Full Access Privacy:** Keyboard extensions requesting Full Access face heavy user skepticism and App Store review scrutiny. Must clearly justify why Full Access is needed. Without it: no network, no iCloud, limited shared container access.
- **Privacy warnings:** iOS shows scary dialog: "allows the developer to transmit anything you type" - many users deny this
- **Data collection restrictions:** Cannot collect sensitive data (passwords, credit cards). Violating this = App Store rejection.
- **No ads allowed:** App Store guidelines prohibit advertising in keyboard extensions
- **Button repurposing banned:** Cannot repurpose keyboard buttons (e.g., holding Return to launch other functions)
- **In-memory store fallback:** When Full Access is denied, must use temporary in-memory Core Data store (data lost on extension termination)
- **Forced unwraps in clipboard operations:** Easy to crash if data types don't match expectations

**Table Stakes Assessment:** **Nice-to-have, not table stakes.**
- Most clipboard managers don't have keyboard extensions (Maccy, CopyQ, Ditto - all desktop, no mobile keyboard)
- Clip's keyboard is marked "beta" even after years
- SnipKey makes it core feature but faces Full Access privacy backlash
- macOS clipboard managers succeed without keyboard extensions
- Friction: Users must enable keyboard in Settings, grant Full Access, switch keyboards mid-typing

**References:**
- [Clip by Riley Testut](https://github.com/rileytestut/Clip) - iOS clipboard manager with keyboard extension (~3 files, ~100 LOC for keyboard)
- [SnipKey](https://github.com/jtvargas/SnipKey) - SwiftUI clipboard keyboard (~4 files, ~900 LOC total)
- [KeyboardKit](https://github.com/KeyboardKit/KeyboardKit) - Framework for custom keyboards
- [TechCrunch: iOS 8 Keyboard Permissions](https://techcrunch.com/2014/10/04/everything-you-need-to-know-about-ios-8-keyboard-permissions-but-were-afraid-to-ask/)
- [Fleksy: Limitations of Custom Keyboards on iOS](https://www.fleksy.com/blog/limitations-of-custom-keyboards-on-ios/)
- [Apple: Custom Keyboard Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html)

---

### 2. Share Extension

**Effort Estimate:** 4-8 hours for basic implementation, 1-2 days for polished version

**Lines of Code:**
- **Minimal implementation:** ~50-100 lines (basic ShareViewController with system UI)
- **Custom UI implementation:** ~150-300 lines (SwiftUI custom view, data validation, App Group sharing)

**Key Files/Targets:**
- New Share Extension target
- ShareViewController.swift (subclass of `SLComposeServiceViewController` or custom `UIViewController`)
- Optional custom SwiftUI view (bridged via `UIHostingController`)
- Info.plist with `NSExtensionActivationRule` (defines accepted data types)
- App Group entitlement for sharing data with main app
- 1-3 Swift files typically

**Key APIs:**
- `SLComposeServiceViewController` (system-provided compose UI) or `UIViewController` (custom UI)
- `NSExtensionContext` and `inputItems` (receive shared content)
- `NSItemProvider` (unwrap shared data by type identifier: public.url, public.text, public.image, etc.)
- App Groups + `UserDefaults(suiteName:)` or shared container for data passing
- `UIHostingController` if using SwiftUI for custom UI

**Complexity Factors:**
- Share Extension is separate process - cannot directly access main app memory
- API hasn't been updated in years - UIKit-only, no native SwiftUI support
- Type handling - must check `NSItemProvider` for multiple data types (URL, text, image, PDF)
- Async data extraction from `NSItemProvider.loadItem`
- App Group setup required for data sharing
- Extension lifecycle - limited memory and time

**Gotchas:**
- `NSExtensionActivationRule` in Info.plist controls when extension appears - default `TRUEPREDICATE` shows everywhere (annoying), must refine for specific types
- Data validation - must handle edge cases (empty content, unsupported types, oversized data)
- No access to main app's in-memory state - everything goes through shared container
- SwiftUI integration is hacky (UIHostingController workaround)
- Limited to receiving content, not browsing clipboard history (Share Extensions don't have access to clipboard history, only current share action)

**Table Stakes Assessment:** **Nice-to-have, not critical.**
- Share Extensions add content *into* clipboard history from other apps
- Useful for "Save to SaneClip" from Safari, Photos, etc.
- But users can already copy and SaneClip captures it automatically
- Adds convenience but not essential functionality
- Common in note-taking apps (Bear, Notion) but less common in clipboard managers

**References:**
- [Apple: Share Extension Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html)
- [Medium: Create iOS Share Extension with SwiftUI (2023)](https://medium.com/@henribredtprivat/create-an-ios-share-extension-with-custom-ui-in-swift-and-swiftui-2023-6cf069dc1209)
- [9series: Build a Share Extension in iOS Using Swift](https://www.9series.com/blog/build-share-extension-ios-using-swift/)
- [AppCoda: Building a Simple Share Extension](https://www.appcoda.com/ios8-share-extension-swift/)
- [GitHub: Share Extension Example](https://github.com/appKODE/share-extension-example-ios)

---

### 3. Shortcuts/Siri Integration (App Intents)

**Effort Estimate:** 4-8 hours for basic intents, 1-2 days for rich integration

**Lines of Code:**
- **Minimal implementation:** ~30-60 lines per intent
- **Full integration:** ~200-400 lines total (3-5 intents: paste item, search clipboard, copy to clipboard, clear history, get recent items)

**Key Files/Targets:**
- No separate target needed (lives in main app)
- 1 file per intent (e.g., `PasteClipboardItemIntent.swift`, `SearchClipboardIntent.swift`)
- Optional: `AppShortcutsProvider.swift` for suggested shortcuts
- Intent definitions are code-based (no .intentdefinition file like old SiriKit)

**Key APIs:**
- `AppIntent` protocol (conform and implement `perform()` method)
- `IntentParameter` for inputs (e.g., search query, item index)
- `AppShortcutsProvider` for pre-defined shortcuts that appear in Shortcuts app
- `AppEntity` if exposing clipboard items as queryable entities
- `@Parameter` property wrapper for intent inputs

**Complexity Factors:**
- **Simple to start:** Basic intent = protocol conformance + `perform()` method
- **Metadata required:** Each intent needs title, description, parameter definitions
- **Scope can expand quickly:** Users expect rich integration (filters, search, parameters, entities)
- **Architecture constraint:** App Intents defined in SPM packages don't work (fundamental limitation) - must be in main app target
- **No specific clipboard history API:** Shortcuts cannot directly access system clipboard history, only current clipboard via `UIPasteboard.general`
- **Data must come from app:** Your app provides clipboard history via App Intents, not system

**Gotchas:**
- App Intents don't work in SPM packages (hours of debugging discovered by developers)
- Starting small is recommended (1-2 intents, expand later) - scope overwhelm is common
- Clipboard access from Shortcuts requires user trust (privacy considerations)
- Unlike keyboard/share extensions, no separate bundle - all in main app
- Testing requires running shortcuts manually (no unit test framework)
- Users must discover intents (not auto-promoted unless you create App Shortcuts)

**Table Stakes Assessment:** **Borderline table stakes for modern iOS apps.**
- Shortcuts integration is increasingly expected in productivity apps
- Enables automation workflows (e.g., "paste last copied URL into Safari")
- Low implementation effort relative to keyboard extension
- No privacy controversy (user explicitly invokes shortcuts)
- Differentiates from basic clipboard managers
- Power users expect this (Reddit/HN feedback on clipboard managers often requests Shortcuts support)
- **Recommendation:** Implement 2-3 core intents (paste item by index, get recent items, search) - high value, low effort

**References:**
- [Superwall: App Intents Field Guide](https://superwall.com/blog/an-app-intents-field-guide-for-ios-developers/)
- [Apple: App Intents Documentation](https://developer.apple.com/documentation/appintents)
- [WWDC22: Implement App Shortcuts](https://developer.apple.com/videos/play/wwdc2022/10170/)
- [WWDC22: Dive into App Intents](https://developer.apple.com/videos/play/wwdc2022/10032/)
- [SwiftLee: App Intent Driven Development](https://www.avanderlee.com/swift/app-intent-driven-development/)
- [Medium: App Intents vs SPM Trade-off](https://medium.com/@bennyyy999/app-intents-vs-spm-the-unexpected-architecture-trade-off-6ac9d03ec26a)
- [Kodeco: Creating Shortcuts with App Intents](https://www.kodeco.com/40950083-creating-shortcuts-with-app-intents)

---

### Summary Table

| Feature | LOC | Files | Effort | Table Stakes? | Key Gotcha |
|---------|-----|-------|--------|---------------|------------|
| **Keyboard Extension** | 800-1000 | 4-5 | 2-4 days → 1-2 weeks | **No** (nice-to-have) | Full Access privacy backlash, App Store scrutiny |
| **Share Extension** | 150-300 | 2-3 | 4-8 hours → 1-2 days | **No** (convenience) | Only receives current share, not clipboard history |
| **App Intents** | 200-400 | 3-5 | 4-8 hours → 1-2 days | **Borderline yes** | Must be in main app target (SPM doesn't work) |

### Recommendation Priority

1. **App Intents (Shortcuts)** - Start here. Low effort, high value, no privacy issues, expected by power users.
2. **Share Extension** - Second priority. Adds convenience, low controversy, moderate value.
3. **Keyboard Extension** - Last priority or skip. High effort, privacy controversy, not table stakes, beta-quality even in mature apps.

---

## CKSyncEngine API

**Updated:** 2026-02-07 | **Status:** verified | **TTL:** 30d
**Source:** Apple Documentation (developer.apple.com/documentation/cloudkit), WWDC 2023 Session 10188

### Overview
CKSyncEngine is a high-level CloudKit API introduced in iOS 17+ / macOS 14+ (WWDC 2023) designed to simplify syncing between devices and iCloud. It encapsulates common sync logic, reducing thousands of lines of custom code to focused event handling.

**Key characteristics:**
- Event-driven architecture via CKSyncEngineDelegate protocol
- Automatic handling of: subscriptions, push notifications, account changes, system conditions, retry logic
- Compatible with existing CloudKit data (can migrate from custom implementations)
- Used by system apps (Freeform, NSUbiquitousKeyValueStore)
- Works with CKRecord and CKRecordZone (standard CloudKit primitives)

### Required Protocol Methods

**CKSyncEngineDelegate** has two required methods:

1. **`handleEvent(_:syncEngine:)`** - Process all sync events
   - Called for every sync operation event
   - Must handle all CKSyncEngine.Event cases (see Event Types below)

2. **`nextRecordZoneChangeBatch(_:syncEngine:)`** - Provide records to upload
   - Called when sync engine is ready to send changes
   - Return `CKSyncEngine.RecordZoneChangeBatch` with records to save/delete
   - Pull from local pending changes queue

### Event Types (CKSyncEngine.Event)

**Fetched changes from server:**
- `.fetchedDatabaseChanges(_:)` - Database-level changes (zone creation/deletion)
- `.fetchedRecordZoneChanges(_:)` - Record changes within zones (creates, updates, deletes)
- `.willFetchRecordZoneChanges(_:)` - Before fetch begins
- `.didFetchRecordZoneChanges(_:)` - After fetch completes

**Sent changes to server:**
- `.sentRecordZoneChanges(_:)` - Results of upload batch (successes and failures)
- `.sentDatabaseChanges(_:)` - Database-level change results

**State and account:**
- `.stateUpdate(_:)` - Sync engine state changed (use for saving serialization)
- `.accountChange(_:)` - iCloud account changed (sign in/out, switch accounts)

### State Serialization (CKSyncEngine.State.Serialization)

**Critical for persistence:**
- `CKSyncEngine.State` tracks pending changes, zone tokens, sync progress
- Must serialize state to disk and restore on launch to avoid re-syncing everything
- Access via `syncEngine.state.serialization` property
- Contains opaque data blob (change tokens, pending changes)

**Pattern:**
```swift
// Save state when it changes
func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) {
    if case .stateUpdate = event {
        let serialization = syncEngine.state.serialization
        // Save serialization data to disk (UserDefaults, file, etc.)
    }
}

// Restore on init
let previousState = // Load from disk
let config = CKSyncEngine.Configuration(
    database: container.privateCloudDatabase,
    stateSerialization: previousState,
    delegate: self
)
```

### Pending Changes Management

**Track local changes before upload:**
- `syncEngine.state.add(pendingRecordZoneChanges:)` - Queue local changes for upload
- `syncEngine.state.remove(pendingRecordZoneChanges:)` - Remove after successful send
- `syncEngine.state.pendingRecordZoneChanges` - View current queue

**Change types:**
- `CKSyncEngine.PendingRecordZoneChange.saveRecord(_:)` - Create/update record
- `CKSyncEngine.PendingRecordZoneChange.deleteRecord(_:)` - Delete by record ID

### Record Zone Setup

**Custom zones required for sync:**
- Default zone doesn't support change tracking or subscriptions
- Create custom `CKRecordZone` (e.g., `CKRecordZone(zoneName: "ClipboardItems")`)
- Add zone as pending database change before adding records
- Sync engine manages zone subscriptions automatically

### Conflict Resolution

**Handling save conflicts:**
- `.sentRecordZoneChanges(_:)` event contains `failedRecordSaves` array
- Each `FailedRecordSave` has error (commonly `.serverRecordChanged`)
- `.serverRecordChanged` error includes:
  - `CKRecordChangedErrorClientRecordKey` - Your attempted save
  - `CKRecordChangedErrorServerRecordKey` - Current server version
  - `CKRecordChangedErrorAncestorRecordKey` - Last known common version (if available)

**Resolution strategy (manual):**
1. Compare client and server records
2. Apply merge logic (last-write-wins, field-level merge, or custom)
3. Re-add merged record to `pendingRecordZoneChanges`
4. Sync engine will retry on next batch

### Swift 6 Concurrency Considerations

**Thread safety requirements:**
- CKSyncEngine itself is **not documented as `Sendable` or an actor**
- Delegate methods are called on arbitrary background queues
- **Best practice:** Use an actor to wrap sync engine and serialize access

**Recommended pattern:**
```swift
@MainActor
class SyncManager: CKSyncEngineDelegate {
    private var syncEngine: CKSyncEngine!

    nonisolated func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) {
        Task { @MainActor in
            await self.processEvent(event)
        }
    }

    nonisolated func nextRecordZoneChangeBatch(...) -> CKSyncEngine.RecordZoneChangeBatch {
        // Must return synchronously - prepare batch in advance or maintain queue
    }
}
```

**Gotchas:**
- `nextRecordZoneChangeBatch` is synchronous (can't await) - maintain pre-populated queue
- Event handling can use async if bridged via `Task`
- CKRecord and CKRecordZone are NOT Sendable - avoid crossing actor boundaries directly

### Integration Checklist

1. ✅ Create CKContainer with iCloud container identifier
2. ✅ Create custom CKRecordZone for app data
3. ✅ Implement CKSyncEngineDelegate (2 required methods)
4. ✅ Initialize CKSyncEngine with configuration + delegate
5. ✅ Restore previous state serialization on launch
6. ✅ Add pending zone creation before first record sync
7. ✅ Map local model objects to CKRecord (encode/decode)
8. ✅ Handle `.fetchedRecordZoneChanges` to update local database
9. ✅ Add local changes to `pendingRecordZoneChanges` when data changes
10. ✅ Implement conflict resolution in `.sentRecordZoneChanges` failures
11. ✅ Save state serialization on `.stateUpdate` events
12. ✅ Handle `.accountChange` for sign-out scenarios (clear local data or pause sync)

### Additional Resources

- **WWDC 2023 Session 10188:** "Sync to iCloud with CKSyncEngine" (primary resource)
- **Apple Docs:** https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/
- **Freeform app** and **NSUbiquitousKeyValueStore** use this API internally (reference implementations)
- **Related:** NSPersistentCloudKitContainer (Core Data + CloudKit, different abstraction level)
