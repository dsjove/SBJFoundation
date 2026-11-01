# SBJDocuments

`SBJDocuments` handles application documents, package-based persistence, attachment storage, export artifacts, and supporting Core Data/SwiftData storage concerns. Choose it when your app owns document lifecycles; use `SBJFileResources` for individual files without a document model.

## Getting started

Prepare an export file in an app-owned temporary directory:

```swift
import Foundation
import SBJDocuments

let writer = ExportArtifactWriter(directoryName: "RecipeExports")
let url = try writer.write(
    Data("Example".utf8),
    named: "recipe",
    extension: "txt"
)
// Present `url` with your application's sharing UI.
```

For package document applications, start with the `PackageDocument` protocols and the `PackageDocumentLibrary` lifecycle rather than implementing ad hoc save operations. `PackageAttachmentStore` and `PackageResourceDirectory` manage content within package structures. Use `CoreDataStorage` for the package's model-container helpers.

