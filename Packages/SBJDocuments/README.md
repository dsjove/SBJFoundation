# SBJDocuments

Document storage and persistence services for applications managing document data. The package provides core-data and document-storage infrastructure, general content storage, and document/file naming helpers. It does not present sharing UI.

## Use

```swift
import SBJDocuments
```

Choose `SBJDocuments` for document lifecycle and storage operations. Choose `SBJFileResources` for standalone file, URL and `FileWrapper` operations that do not require a document model. SwiftUI sharing surfaces are provided by the application presentation layer.

## Dependencies

`SBJLocalization` and `SBJFileResources`. No dependency on `SBJFoundation`.

## Tests

Package tests cover document-library behavior and ordering semantics. Consumers should separately test their own persistence and migration requirements.
