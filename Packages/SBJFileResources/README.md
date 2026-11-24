# SBJFileResources

`SBJFileResources` provides file-resource primitives for clients that need to store or inspect resource content, work with bundled assets, manage security-scoped file access, attach resources to models, or persist small preferences. It does not own an application’s complete document lifecycle.

## File content and wrappers

Use checked `FileWrapper` readers at the boundary of data loaded from disk:

```swift
import Foundation
import SBJFileResources

func readBytes(_ wrapper: FileWrapper) throws -> Data {
    try wrapper.sbjRegularFileContents()
}
```

`sbjRegularFileContents()` and `sbjDirectoryContents()` throw Swift errors for the wrong wrapper kind rather than accessing Foundation properties with Objective-C preconditions. `SBJResourceContent` carries encoded bytes, a `UTType`, and the storage representation (`regularFile` or `directory`). When loading existing wrappers, use `init?(storageFileWrapper:filename:fallbackContentType:)` to preserve directory/package shape even when the filename extension is unknown.

`SBJResourceSource` distinguishes immediately available, read-only content from deferred asynchronous loading and saving. Its optional `hasContent` is an availability hint: `nil` means *unknown*, not *false*. Deferred operations run on the main actor.

## Bundled resources

`SBJBundledContentReference` describes either an asset-catalog data asset or a named bundle resource. Supply the actual bundle when resources are shipped by a framework or Swift package rather than the main app. `dataValue()` and `stringValue()` return `nil` if content is unavailable. `SBJBundledContentReference.help` targets the conventional `help` subdirectory.

## File permissions and bookmarks

A URL and permission to access it are distinct. `withSecurityScopedAccess` scopes a **synchronous** operation; `SecurityScopedFileURL.beginAccess()` and `ScopedDirectory.beginAccess()` return leases suitable for longer-lived asynchronous consumers. Release the lease after the operation or player no longer uses the URL. Successful scope acquisition does not replace normal filesystem error handling.

`BookmarkedURLWithFallback` stores a security-scoped bookmark where supported and a readable path for unavailable volumes. `resolve()` may return the **path fallback**, which is not evidence of current authorization. Use `scopedDirectory()` when the operation needs a bookmark-backed directory. A path retained for display should not be treated as an access grant. Explicit `save(_:)` stores the new path first and removes any old bookmark; if bookmark creation fails, the new display path remains without an old selection’s permission.

`ScopedDirectory.file(at:)` checks the relative path and `ScopedFile.checkedURL()` rejects paths that resolve outside its root (including symbolic-link escapes). Check the resolved path before file I/O. As with other path checks, concurrently changing symlinks cannot be ruled out; do not treat this as a hardened sandbox boundary.

## Attachments

`Attaching` is a storage-neutral model contract; `BookmarkAttaching` adds persistent external-file bookmarks. `AttachmentOwner` provides name collision handling, sorting, and identity-based removal. `URLAttachment` describes content intended for preview or sharing; embedded content is materialized to a uniquely named temporary directory. The caller manages temporary-file retention and cleanup appropriate to its workflow.

Use `validateAttachmentURL(maximumAttachmentBytes:)` to apply the provided policy for regular files and file packages. `embeddedSize(maximumBytes:)` counts regular-file bytes and does not follow symbolic links; exceeding the limit stops traversal early. These are logical file sizes, not compressed disk usage. Alternative attachment policies should be implemented by the client.

## URL and filename utilities

`readWebLink()` reads the HTTP(S) destination of a local `.webloc` property list. `mediaContentType` uses filesystem metadata when available and otherwise infers a type from the extension. Remote URLs are not classified as local media files by these helpers.

`sanitizedFilename`, `uniqueFilename(existingNames:)`, and `uniqueNumberedDestination(in:)` handle filename normalization and collision candidates. These helpers do not reserve a file atomically; the client must handle a race when creating the destination.

**URL opening:** The existing `URL.open`, `URL.open(accessing:)`, and folder/Finder-opening helpers have their established platform-specific request and completion behavior. This iteration intentionally leaves all URL-opening implementation unchanged. A queued UIKit open request is not a guarantee of successful launch.

## Preferences

`@DefaultsStorage` supports native property-list values, `UUID`, `URL`, raw-representable types, and supported optionals with a caller-defined fallback. Use a dedicated `UserDefaults` suite when isolating distinct persistence domains. General `Codable` persistence is not provided by this wrapper.

## Scope

For document lifecycle operations, use `SBJDocuments`. For user-facing share and export presentation, use `SBJSharing`. Domain nomenclature, accessibility, and semantic value contracts are provided by `SBJLocalization`, on which this package depends.
