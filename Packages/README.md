# Nested package scaffolds

No existing production source files have been moved.

- `SBJShared`: temporary shared dependencies, no higher-level package dependencies.
- `SBJDocuments`: **one package, one module**, with planned source folders `DocumentStorage`, `CoreDataStorage`, and `Sharing`. Depends on `SBJShared`.
- `SBJSubject`: data definition and localization prototypes; depends on `SBJShared`; own macro target.
- `SBJSubjectEditor`: SwiftUI editor and editor macros; depends on `SBJSubject` and `SBJShared`.

The existing `SBJFoundation` sources and macros remain unchanged. All new modules contain placeholders only.
