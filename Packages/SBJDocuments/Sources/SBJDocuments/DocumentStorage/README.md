# DocumentStorage

`DocumentStorage` is SBJFoundation's reusable storage layer for apps whose primary user data is an app-owned document/package rather than a database model graph.

The design goal is that an app describes its document semantics and package format while SBJFoundation owns the difficult file-lifecycle mechanics: canonical document identity, iCloud/local storage location, coordinated reads and writes, active document sessions, import/export, external changes, and conflict handling.

## Design principles

### One canonical live object per document identity

`PackageDocumentLibrary` maintains the canonical in-memory document for each stable document ID. Callers should ask the library to open/create/import/duplicate documents rather than manufacturing parallel live instances for the same persisted package.

### Stable identity is separate from the user-facing name

A package's storage filename is derived from the document's stable ID through `PackageStorageLocation`. The document's displayed name may change without changing its storage identity. String IDs use a URL-safe Base64 representation by default rather than a display name.

### The app owns document meaning; Foundation owns storage mechanics

A `PackageDocument` supplies:

- its immutable `Snapshot` representation;
- stable ID, name, role, and modification date;
- creation/duplication/import policy;
- conversion between snapshots and `FileWrapper` package contents;
- optional app/deep-link URL routing;
- its storage location.

`PackageDocumentLibrary` supplies:

- library discovery;
- active package sessions;
- canonical live-object identity;
- save coalescing/session lifecycle;
- imports and import collisions;
- package export;
- external file moves/deletions/modifications;
- conflict resolution;
- iCloud/local directory monitoring.

This split is intentional. Do not move app-specific package contents or document-domain rules into SBJFoundation merely because they are used during persistence.

## Primary public API

### `PackageDocumentSnapshot`

A lightweight immutable value describing persisted document state. It must expose a stable comparable/hashable ID and be `Sendable`.

### `PackageDocument`

The app-facing document contract. A conforming reference type represents the live document and can restore itself from a snapshot.

Important requirements:

- `snapshot` must contain everything required to persist the document;
- `restore(from:)` must make an existing live object represent the supplied persisted state;
- `markModified(at:)` updates domain modification metadata;
- `makeNewDocument()` and `makeDuplicate(of:named:)` own app policy;
- `prepareImport` / `finalizedImport` own identity policy for imports and copies;
- `fileWrapper(for:)` defines the complete detached/export package representation;
- `persist(_:to:)` defines active-save behavior and may update a coordinated package incrementally;
- `snapshot(from:)` / `catalogSnapshot(at:)` define package loading and discovery.

### `PackageDocumentLibrary`

The main client-facing storage object. It is `@MainActor` and `@Observable`.

Typical flow:

```swift
let library = PackageDocumentLibrary<MyDocument>(builtInDocuments: builtIns)
try await library.load()

let document = try await library.createDocument()
library.documentDidChange(document) { error in
    // App-specific error presentation/logging.
}
```

Use the library for create, open, duplicate, import, delete, export, and conflict resolution. Do not write directly into the package directory while the package is managed by a live library session.

### `DocumentRole`

Distinguishes user-owned documents from built-in/debug documents. Only user documents participate in normal persisted deletion and package-session behavior.

### `DocumentURLRouting`

Optional stable-ID routing for app/deep links. The default implementation opts out by returning `nil`.

### Import conflicts

`PackageImportConflict` and `PackageImportConflictResolution` represent a source package whose stable ID collides with an existing library document. The app chooses whether to replace the existing identity or import the incoming package as a copy.

### External conflicts

`PackageExternalConflict` and `PackageExternalConflictResolution` represent a package modified, moved, or deleted by an external actor while the app has a live document/session. Foundation detects the conflict; the app decides whether to keep current in-app changes or accept the external state.

### Export helpers

`ExportArtifactWriter` stages export artifacts in an app-controlled temporary directory. `ExportDestinationService` copies one or more staged artifacts into a user-selected destination and reports collisions rather than silently overwriting.

These helpers are public because apps may export data other than a complete `PackageDocument` package. Their filesystem implementation details remain internal.

## iCloud behavior

`PackageStorageLocation` uses an explicit storage policy. `.local` always uses the app Documents directory; `.iCloudPreferred(...)` uses the configured ubiquitous Documents directory when available and otherwise pins that library instance to local Documents storage.

This is document-based iCloud storage, not CloudKit database synchronization. File coordination and file versions matter. `PackageSession` and the directory monitor intentionally hide platform-specific details from clients.

External changes are not assumed to be harmless. If an external change arrives while the app has unsaved state, the library records a conflict instead of automatically discarding one side.

## Import identity

Import is deliberately two-stage:

1. load and validate the external package;
2. let the app normalize it with `prepareImport`;
3. detect stable-ID collision;
4. resolve collision if necessary;
5. finalize the imported snapshot with `finalizedImport(_:asCopy:)`.

A copy must receive whatever new identity the app's domain requires. Do not solve import collisions by modifying filenames alone; package filename is derived from stable document identity.

## Save behavior

The live document remains the app's mutable object. `documentDidChange` snapshots its state into the active package session and updates the library catalog. Platform-specific sessions own coordinated persistence.

The app supplies an error callback because Foundation can detect a failed save but cannot decide how disruptive that failure is to the user's workflow.

## Conflict and failure philosophy

DocumentStorage favors preserving both user intent and recoverability over silent conflict resolution:

- transient provider failures while loading one package do not discard the rest of the library;
- unsaved local changes prevent automatic acceptance of an external removal;
- import collisions are explicit;
- destination export collisions are explicit;
- package identity does not depend on mutable display names.

## Public-surface policy

DocumentStorage intentionally exposes the domain contracts and operations an app must invoke. Helper/session/catalog/file-coordination implementation types are internal.

When adding new behavior, prefer:

1. implementing generic mechanics internally;
2. exposing a public operation only when an app must request it or provide domain policy;
3. avoiding public convenience APIs whose only caller is another SBJFoundation type.

This keeps future implementation changes possible without creating permanent package API commitments.

## What does not belong here

Do not put these in DocumentStorage solely because they touch a document:

- app-specific model types;
- app-specific editors/views;
- package-specific filenames or directory structure;
- domain merge rules;
- arbitrary user preferences;
- database/SwiftData/CloudKit record synchronization.

The database counterpart is `CoreDataStorage`.

## Testing expectations

Changes to DocumentStorage should test at least the behavior they affect, particularly:

- stable-ID package naming;
- import collisions and copy identity;
- external modification/removal conflicts;
- built-in versus user document behavior;
- package export;
- coordinated file replacement;
- canonical live-object preservation.

Tests may use internal initializers/file managers through `@testable import`; those seams do not need to become public merely to support tests.
