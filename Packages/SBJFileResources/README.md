# SBJFileResources

General-purpose file resource primitives, independent of document lifecycle and UI frameworks.

- `SBJResourceContent` and validated `FileWrapper` operations
- `String.sanitizedFilename` and `uniqueFilename`
- `URL.withSecurityScopedAccess`
- `SBJBundledContentReference` and `Bundle.sbjResourceURL`

SBJDocuments and SBJFoundation depend on this package. Attachment-specific validation, image presentation, app icon retrieval and document lifecycle remain in their existing modules.
