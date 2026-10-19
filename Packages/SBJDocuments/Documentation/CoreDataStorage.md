# CoreDataStorage

`CoreDataStorage` is SBJFoundation's reusable persistence layer for apps backed by SwiftData/Core Data, including apps synchronized through CloudKit.

Its goal is not to hide SwiftData. Its goal is to centralize the lifecycle rules that are easy to get subtly wrong in production: container construction, save behavior, deterministic model insertion/deletion, teardown, logical-root reconciliation, remote-store observation, duplicate-ID repair, and recoverable destructive migrations.

The guiding rule is **Foundation does the generic correct thing with minimal client intervention; the app supplies only domain policy that Foundation cannot know.**

## Terminology

The source directory is named `CoreDataStorage` because SwiftData is built on the Core Data persistence family and many CloudKit/runtime behaviors surface through Core Data APIs and notifications. Most client-facing APIs currently use SwiftData types such as `ModelContainer`, `ModelContext`, and `PersistentModel`.

## Production compatibility comes first

These utilities are intended for apps with existing users and existing synchronized data.

A production CloudKit-backed model is not disposable development state. Before changing persisted model declarations or destructive repair logic, consider all three simultaneously:

1. the existing local store;
2. the deployed CloudKit schema/data;
3. older released app versions that may still synchronize with the same container.

`TODO(CoreDataStorage production compatibility)` comments mark places where this constraint is known to matter.

Do not remove or rename persisted fields merely because current source no longer uses them. A deprecated property may need to remain in the model indefinitely for store/CloudKit compatibility.

## Primary public API

### `CoreDataStorage.makeModelContainer`

Creates a SwiftData `ModelContainer` from model types and a schema version, optionally using in-memory storage.

```swift
let container = try CoreDataStorage.makeModelContainer(
    for: [Root.self, Item.self],
    version: .init(1, 0, 0),
    cloudKitDatabase: .automatic
)
```

This is construction plumbing only. Calling it does **not** make an incompatible production schema change safe.

### `ModelContext.saveIfNeeded()`

Use when failure is part of control flow and the caller cannot safely continue without a successful local commit.

```swift
try context.saveIfNeeded()
```

It avoids a redundant save when `hasChanges == false` but otherwise preserves normal throwing behavior.

### `ModelContext.saveChanges()`

Use for routine UI persistence where every transient failure should not become a user alert or a repetitive local `do/catch` block.

```swift
context.saveChanges()
```

It centralizes diagnostics and returns `ModelContextSaveResult` if a caller needs to inspect the outcome.

Do not use the nonthrowing form for a migration/reconciliation phase whose next destructive step assumes the save succeeded.

### `PersistentModel.insertNow`

Provides one consistent insertion path:

1. insert into the supplied context if necessary;
2. populate relationships/state;
3. optionally save.

It rejects an attempt to silently move a live model from one context to another.

```swift
let item = Item()
item.insertNow(context) { item in
    item.owner = owner
}
```

### `PersistentModel.deleteNow`

Provides one deterministic deletion path. If the model conforms to `Teardownable` using the migrated preparation-only contract, Foundation runs teardown before calling `ModelContext.delete` and optionally saving.

Deletion in a CloudKit store is synchronized destructive behavior. A production migration/reconciliation should create a logical recovery snapshot before deleting user data.

### `Teardownable`

Use for a model/resource that requires explicit relationship or external-resource cleanup before deletion.

New code should treat:

```swift
func tearDown()
```

as **prepare for deletion**, not as "delete self." `deleteNow()` owns the actual persistent deletion.

`tearDownDeletesSelf` and the historical `TearDownable` spelling are temporary compatibility for older clients. They are intentionally marked for removal after the remaining apps migrate.

### `CoreDataStorage.ensureLogicalRoot`

CloudKit-backed stores cannot safely assume that a logical singleton is always represented by exactly one physical local record. Two devices can independently create a root before synchronization converges.

`ensureLogicalRoot` handles the generic lifecycle:

```text
fetch roots
→ create one if none exists
→ deterministically choose canonical root
→ ask app to merge duplicate domain state
→ save merged ownership/state
→ delete duplicate roots
→ save deletion
```

The app supplies only:

- a stable `canonicalKey` that imposes deterministic ordering;
- creation of a new root;
- a domain `merge(duplicate, canonical)` closure.

The merge closure must preserve meaningful user data and should be idempotent.

The result exposes the canonical root and duplicate count. Construction details that clients do not currently require remain internal to keep API surface small.

Important: this reconciles duplicates **after they exist**. It does not attempt to prove that an initial CloudKit import has finished; SwiftData does not provide a reliable semantic "there is definitely no cloud root" boundary. Correctness comes from convergence, not waiting on a timer.

### `PersistentStoreRemoteChangeObserver`

Owns the Core Data remote-store notification plumbing and delivers callbacks on `MainActor`.

```swift
observer = PersistentStoreRemoteChangeObserver {
    // Domain reconciliation / cache refresh.
}
```

Foundation observes the store. The app currently decides which domain caches/roots need refresh because Foundation cannot infer arbitrary app-owned state. A TODO records that this may become a higher-level coordinator if the remaining apps demonstrate the same sequence.

### `ModelContext.repairDuplicateUUIDs`

Repairs duplicate UUID values by preserving one record's existing UUID and assigning fresh IDs to later collisions.

This is intentionally a low-level repair primitive. It is **not automatically safe** when another persisted field stores that UUID as a manual foreign key. Audit and repair such references together at the app/domain layer.

Use it only as part of an idempotent data-repair pass.

### `CoreDataRecoveryArchive`

Stores app-defined Codable logical recovery snapshots in Application Support before destructive production migrations/reconciliation.

Foundation owns:

- atomic writing;
- rolling retention;
- listing snapshots;
- decoding a selected snapshot.

The app owns the snapshot schema and restore semantics.

```swift
let url = try CoreDataRecoveryArchive.write(
    snapshot,
    appIdentifier: "Meals",
    label: "pre-reconciliation"
)

let entries = try CoreDataRecoveryArchive.list(appIdentifier: "Meals")
let restored = try CoreDataRecoveryArchive.read(MySnapshot.self, from: url)
```

CloudKit is synchronization, not backup. Installing an older app binary does not restore data that a destructive migration already synchronized to every device.

## Recovery design

For production apps, destructive persistence work should follow this pattern:

```text
detect that repair/reconciliation is actually needed
→ encode a complete logical snapshot
→ atomically store recovery archive
→ abort destructive migration if backup fails
→ perform idempotent repair/reconciliation
→ save required phases with throwing saves
```

A useful snapshot should preserve domain information that the new code is about to discard, including deprecated fields when necessary. The snapshot format is app-owned because only the app understands the logical graph and how to reconstruct it safely.

A restore should itself snapshot current state before replacing it, creating an undo point for the recovery operation.

Raw SQLite/WAL file copying is deliberately not the primary recovery abstraction. Logical snapshots are portable across current model implementations and can be restored through normal model APIs.

## Data repair rules

### Repairs should be idempotent

A repair may run at launch and again after remote CloudKit changes. "Already repaired" records should not be modified again merely because assignments are harmless. Repeated no-op assignments can dirty contexts and create unnecessary synchronization traffic.

### Do not use per-device flags as proof synchronized data is migrated

A `UserDefaults` "migration completed" flag can become stale when old records arrive later from CloudKit. Prefer inspection of the actual record and repeatable repair.

If a genuinely expensive versioned migration is required, design that explicitly and preserve recoverability.

### Separate schema compatibility from logical cleanup

Keeping a deprecated persisted field in the schema does not require continuing to use it in current domain logic. Conversely, clearing that field is a synchronized data mutation and may break older app versions that still read it.

Treat model declaration compatibility and data cleanup as separate decisions.

## CloudKit considerations

### Eventually consistent roots

Do not block startup on an arbitrary timeout waiting for CloudKit. A device may initially see no root, create one, and later import an older root. `ensureLogicalRoot` is designed to converge this temporary duplicate state deterministically.

### Two-phase duplicate deletion

Logical-root reconciliation saves transferred/re-parented content **before** deleting duplicate roots. This is important when root relationships use cascade deletion. If duplicate deletion fails, the already-saved merge remains durable and a later reconciliation can retry the deletion.

### Remote changes can invalidate in-memory caches

SwiftData may contain newly imported data while an app-owned cache still reflects the previous fetch. Apps currently refresh such caches in the remote-change callback. Do not assume a successful CloudKit import automatically invalidates arbitrary application caches.

### Merge/conflict policy is domain-sensitive

Foundation can choose a deterministic physical root but cannot know how two conflicting shopping trips, settings, or domain values should merge. Expose only the smallest domain hook necessary. Add framework strategy APIs only after another real app demonstrates a repeated need.

## Save/error philosophy

Routine UI saves should not produce a user alert for every transient persistence error. Infrastructure operations that establish invariants must not silently continue after a failed save.

Therefore CoreDataStorage deliberately offers both:

- nonthrowing/logging `saveChanges()` for routine persistence;
- throwing `saveIfNeeded()` for operations whose correctness depends on the commit.

`TODO(CoreDataStorage strategy)` marks the unresolved question of automatic retry/escalation. Do not invent a broad error taxonomy until the remaining production apps provide concrete cases.

## Concurrency and context ownership

A persistent model belongs to its `ModelContext`. `insertNow` does not silently transfer a live model between contexts.

Current logical-root and repair APIs that mutate the primary UI store are `@MainActor` where appropriate. If later apps introduce true background-context workflows, extend the API from those concrete requirements rather than weakening actor guarantees preemptively.

Do not pass live model objects between unrelated contexts/tasks and assume SwiftData will reconcile ownership automatically.

## Public-surface policy

CoreDataStorage follows the same surface rule as DocumentStorage:

> expose only what a client app must invoke, conform to, inspect, or supply as policy.

Implementation conveniences remain internal even when generic. Examples currently kept internal include result construction and unused model lookup/save shortcuts.

When extending this area:

1. first solve the generic mechanism internally;
2. make it public only when an app must call it across the package boundary;
3. prefer one policy closure/strategy at a genuine domain contention point over a collection of speculative configuration options;
4. record unresolved contention points with detailed `TODO(CoreDataStorage ...)` comments so analysis survives until another app provides evidence.

## What does not belong here

Keep these in the app unless repeated evidence from another production app proves they are generic:

- app model/schema definitions;
- domain seed content;
- domain-specific duplicate merge rules;
- decisions about which conflicting user value wins;
- arbitrary cache implementations;
- UI for recovery/support;
- domain migration semantics.

Generic tag persistence/UI is planned as a separate Foundation subsystem rather than being embedded into CoreDataStorage itself.

## Suggested production migration checklist

Before shipping persistence changes:

1. compare current model declarations with the last production model;
2. identify deployed CloudKit fields/relationships that must remain;
3. consider behavior of older app versions still syncing;
4. identify every destructive or identity-changing repair;
5. ensure a complete logical recovery snapshot is written first;
6. verify snapshot failure aborts destructive work;
7. make repair idempotent;
8. use throwing saves between invariant-dependent phases;
9. test duplicate roots and conflicting child data;
10. test duplicate IDs plus any manual foreign-key IDs;
11. test remote-change arrival after launch;
12. test restore from a real pre-migration snapshot;
13. retain detailed production-compatibility TODOs where policy is unresolved.

## Testing expectations

CoreDataStorage changes should be tested against both clean and already-populated stores. Important scenarios include:

- zero/one/multiple logical roots;
- merge failure before duplicate deletion;
- deletion failure after successful merge;
- idempotent reruns;
- duplicate UUID repair;
- teardown ordering;
- save with and without pending changes;
- remote-store callbacks;
- snapshot write/list/read/retention;
- snapshot restoration through an app's current model layer.

Where possible, tests should use in-memory containers for mechanics and explicit fixtures representing older production data for migration behavior.
