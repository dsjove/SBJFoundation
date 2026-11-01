# SBJFileResources

`SBJFileResources` covers typed file content, bundled-resource references, URLs, security-scoped access, file wrappers, attachments, and small persistence helpers. It intentionally does not manage complete application document lifecycles.

## Getting started

When reading untrusted `FileWrapper` contents, use the checked accessors instead of accessing the wrong wrapper kind:

```swift
import Foundation
import SBJFileResources

func bytes(from wrapper: FileWrapper) throws -> Data {
    try wrapper.sbjRegularFileContents()
}
```

`sbjRegularFileContents()` throws if the wrapper is not a regular file; `sbjDirectoryContents()` is the equivalent for directories. To pass data together with a Uniform Type Identifier, use `SBJResourceContent(data:contentType:)`. `SBJBundledContentReference` represents content shipped with a module or app. `URLAttachment` and the attachment protocols support model-level file references.

Use `SBJDocuments` when file operations are part of a document library, and `SBJSharing` when they need user-facing export or share presentation.
