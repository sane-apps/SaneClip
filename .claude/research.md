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
