# SBJShared (transitional package)

Temporary home for code required by two or more of **SBJSubject**, **SBJSubjectEditor**, and **SBJDocuments**, when that code has no better owner yet.

## Dependency rule

SBJShared must **not** depend on SBJSubject, SBJSubjectEditor, or SBJDocuments. Those packages may depend on SBJShared. Avoid putting subject/editor/document-specific abstractions here solely to avoid resolving the correct ownership.

## Migration rule

Before moving each declaration:
1. Identify all usages, extensions, conformances, and macro-generated references.
2. Check platform requirements (especially SwiftUI, UIKit, AppKit, CoreData, and SwiftData).
3. Move the declaration and tests together.
4. Update consumer imports and dependency manifests.
5. Compile and test each affected package.

## Working structure (planned)

- `Packages/SBJDocuments/DocumentStorage/`
- `Packages/SBJDocuments/CoreDataStorage/`
- `Packages/SBJDocuments/Sharing/` (sharing belongs to documents)
- `Packages/SBJSubject/` (data definition, property info, first-class Codables, localization prototypes and model macros)
- `Packages/SBJSubjectEditor/` (SwiftUI editing, editor support and **separate editor macros**)
- `Packages/SBJShared/` (temporary cross-cutting support)

These other package directories are **not created** by this scaffold. The existing SBJFoundation target remains intact until a verified migration can be performed.

When the last consumer of a declaration is in one feature package, move it to that package and remove it from SBJShared.
