# SBJDocuments

Document and persistence support for applications that use **file packages** or **SwiftData/Core Data**. These are separate storage models; choose the API that matches your application's ownership of its data.

## Choose the right API

| Your application needs | Start with |
| --- | --- |
| A library of app-owned file packages with local or iCloud Documents storage | `PackageDocument`, `PackageDocumentSnapshot`, `PackageDocumentLibrary` |
| Named attachments inside a package | `PackageAttachmentStore`, `PackageResourceDirectory` |
| Staged exports and user-selected destinations | `ExportArtifactWriter`, `ExportDestinationService` |
| A SwiftData model container and explicit save policy | `CoreDataStorage`, `ModelContext` extensions |
| A single logical root across eventually synchronized CloudKit data | `CoreDataStorage.ensureLogicalRoot` |
| Backups before destructive model migrations | `CoreDataRecoveryArchive` |

`SBJFileResources` remains the smaller dependency for standalone file and security-scoped URL operations. `SBJDocuments` re-exports it for existing clients.

## Package document libraries

Define a sendable, equatable `PackageDocumentSnapshot` and a `PackageDocument` reference type. The document owns its domain state, serialization, import rules, and stable identity. `PackageDocumentLibrary<Document>` owns discovery, the canonical live object for each ID, save sessions, coordination, import conflicts, external changes, and deletion.

```swift
import SBJDocuments

// MyDocument conforms to PackageDocument.
let library = PackageDocumentLibrary<MyDocument>(builtInDocuments: [])
try await library.load()
let document = try await library.createDocument()

// After mutating the document's domain state:
library.documentDidChange(document)
try await library.save(document)
```

The library is main-actor isolated. Open user documents through the library so they have a persistence session; do not independently edit their package directories. Save/flush errors are meaningful: use `save(_:)` or `flushAllRequiringSuccess()` when the application must know that a durable write has succeeded.

Storage is selected through `PackageStorageLocation` at library creation. `.local` uses local Documents. `.iCloudPreferred` uses iCloud Documents when available and otherwise uses local Documents **for that library instance's lifetime**; it does not silently merge the two catalogs later. Document-based iCloud file synchronization is different from SwiftData's CloudKit database synchronization.

A metadata-visible cloud package may not be downloaded yet. Its presence is preserved during catalog scans; unreadable packages are not automatically treated as deletions. The library exposes explicit import and external-change conflicts for the application to resolve.

## SwiftData and CloudKit

`CoreDataStorage.makeModelContainer` constructs a SwiftData container. The `ModelContext` helpers provide both `saveIfNeeded()` (throwing, for required commits) and `saveChanges()` (diagnostic result, for routine UI persistence).

`ensureLogicalRoot` reconciles physical duplicates from independent devices using a stable client-supplied ordering key and merge closure. It cannot prove that initial CloudKit synchronization is complete. Merge policy and recovery snapshots remain the application's responsibility; deletion after reconciliation can propagate to other devices.

For a destructive migration, use `CoreDataRecoveryArchive.write` with an app-defined `Codable` logical snapshot and a single safe application identifier, and verify recovery before modifying persistent data. Snapshots are stored locally in Application Support, not automatically backed up by CloudKit. Treat them as potentially sensitive user data.

## Exporting files

```swift
let writer = ExportArtifactWriter(directoryName: "MyAppExports")
let staged = try writer.write(Data("example".utf8), named: "report", extension: "txt")
let destinationService = ExportDestinationService()
let outcome = try destinationService.export(
    [staged],
    to: selectedDirectory,
    replacingExisting: false
)
// Handle .needsReplacement by asking the user before repeating with true.
```

A failed replacement copy leaves the existing destination intact. Multi-file export is **not** an all-or-nothing transaction: if a later file fails, earlier files may already have been exported. Do not delete staged files until the export completes successfully.

## Platform considerations

The package declares iOS 17, macOS 14, Mac Catalyst 17, watchOS 10, visionOS 1, and tvOS 17 as minimums. Package-document session APIs are conditionally excluded on watchOS; UIKit document sessions and coordinated-file sessions are selected by supported platform. An operating-system deployment minimum does not imply iCloud entitlement or CloudKit availability. Applications must configure their own entitlements and containers.

## Detailed client contracts

- [Document storage, lifecycle, conflicts, and iCloud Documents](Documentation/DocumentStorage.md)
- [SwiftData/Core Data, logical roots, migrations, and CloudKit](Documentation/CoreDataStorage.md)
- [Document persistence implementation notes](Documentation/DocumentStorageSupplement.md)

The library does not decide domain-specific merge or schema-migration rules. Future coordination conveniences should be introduced only after their behavior is supported by real client requirements.
