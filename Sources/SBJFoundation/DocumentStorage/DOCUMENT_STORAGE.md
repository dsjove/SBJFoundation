# Document Storage

SBJFoundation’s document-storage feature provides a small client-facing package-document API and keeps the platform-specific persistence machinery internal. Applications describe a live document and its immutable persisted snapshot; `PackageDocumentLibrary` owns persistence and canonical live identity.

## Client-facing contract

Applications use these types directly:

- `PackageDocumentSnapshot` — immutable, sendable persisted state with a stable ID.
- `PackageDocument` — live-document contract for snapshot/restore, display name and role, creation/duplication, storage configuration, import policy, deep-link routing, and `FileWrapper` serialization.
- `DocumentRole` and `DocumentURLRouting` — document policy used by `PackageDocument` conformers.
- `PackageStorageLocation` and `PackageStoragePolicy` — explicit construction-time storage configuration returned by a document type. Generic document IDs can provide their own storage-name mapping.
- `PackageDocumentLibrary<Document>` — the application-facing library for discovery, canonical live objects, open/create/duplicate/delete/import/export, persistence state, semantic notices, package URLs, and conflict resolution.
- `PackageDocumentNotice` — queued semantic informational notices. Apps may present these themselves or opt into the standard `.packageDocumentAlerts(...)` SwiftUI adapter.
- `PackageImportConflict`, `PackageImportConflictResolution`, `PackageExternalConflict`, `PackageExternalConflictKind`, and `PackageExternalConflictResolution` — conflict information and choices surfaced by the library.
- `ExportArtifactWriter` — staging helper for app-owned export artifacts.
- `ExportDestinationService` — copies staged exports to a user-selected directory and reports replacement collisions before overwrite.

The public surface is intentionally limited to behavior a client currently needs. Internal implementation types are not API promises and should not be made public for hypothetical reuse.

## Internal persistence machinery

`PackageDocumentLibrary` internally owns the package catalog, coordinated file access, active package sessions, iCloud-directory monitoring, and Foundation file-version conflict handling.

- `PackageLibraryStore` performs coordinated package discovery, deletion, and external package reads.
- `CoordinatedFileAccess` and `SecurityScopedResourceAccess` handle coordinated/security-scoped URL access.
- `UbiquitousDirectoryMonitor` observes the active package directory for catalog changes.
- `PackageSession` is the active-file backend. On UIKit document platforms it is backed by `UIDocument`; tvOS uses an `NSFilePresenter`/`NSFileCoordinator` implementation because `UIDocument` is unavailable there.
- `PackageSessionEvent` and version-resolution helpers connect the active session to the library.

These types exist to implement `PackageDocumentLibrary`; applications should not depend on them or branch on the active-session backend.

## Storage lifetime

A document type returns a `PackageStorageLocation` from `storageLocation(fileManager:)` with an explicit `.local` or `.iCloudPreferred(...)` policy. The library resolves its active root once during initialization (or accepts an injected root for tests) and uses that root for its lifetime. This prevents the package catalog and active sessions from diverging if iCloud availability changes while the library is alive.

Canonical package names are based on stable document IDs rather than user-facing names. Display-name-based export naming is a client/export policy, not canonical storage identity.

## Conflict policy

Import conflicts are detected by stable document ID before adoption. The client chooses whether to replace the existing document or import the incoming package as a copy.

For an open package, Foundation `NSFileVersion` is used under coordinated access for content conflicts. Keeping local changes saves the current state and resolves competing versions. Choosing the external version promotes the selected external file version and reloads the session. External move/delete conflicts discard a pending stale save before closing; choosing to keep local changes then recreates only the canonical package location.

Clients receive conflict descriptions and submit a resolution through `PackageDocumentLibrary`; the file-version/session mechanics remain internal.


## Opening and write compatibility

`document(id:)` is lookup only. `open(_:)` and `open(id:)` establish an active persistence session for user documents before returning them. A user document that cannot be backed by its persisted package fails to open rather than appearing editable without a save path.

A document format may declare a decoded snapshot readable but not writable through `PackageDocument.isSnapshotWritable(_:)`. This supports forward-compatible viewing without silently rewriting a newer schema through an older encoder. Mutation, duplication, import adoption, and package export reject non-writable snapshots; clients can use the document model's corresponding editability state to disable those actions in advance.
