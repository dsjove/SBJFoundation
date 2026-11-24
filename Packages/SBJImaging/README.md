# SBJImaging

`SBJImaging` provides image references, photo acquisition and editing, non-destructive image documents, thumbnail presentation, and movie/poster workflows. It is a user-facing media package; it does not replace `SBJCamera` for capture, `SBJFileResources` for file permissions and resource storage, or `SBJDocuments` for general document persistence.

## Choosing an API

| Client requirement | API |
| --- | --- |
| Show a symbol, asset, bundled resource, or file-backed image | `ImageReference` |
| Import, view, replace, edit, or remove a bound image | `PhotoMenu` and `SBJResourceContent` |
| Show a single image without editing | `PhotoViewer` / `PhotoDisplayView` |
| Edit pixels or return a non-destructive editing recipe | `PhotoEditor`, `PhotoEditResult` |
| Save source plus non-destructive edits in one package | `SBJImageDocument` |
| Save images to the system photo library | `PhotoLibrary` |
| Read or update a movie's embedded poster artwork | `getPosterFrame`, `hasPosterFrame`, `setPosterFrame`, `clearPosterFrame` |
| Display thumbnails from selected movie times | `PosterFrameCache`, `CachedPosterThumbnail` |
| Play movies and offer poster/frame actions | `MovieViewer`, `MovieViewerOptions`, `MoviePosterAction` |
| Join movie files or append selected media | `MovieFolderJoiner`, `MovieJoinCoordinator`, `MovieAppendWorkflow` |

Import with `import SBJImaging`. Models are separated from SwiftUI controls where the underlying functionality permits it. Some operations require user-granted security-scoped file access or photo-library permissions. The application owns those permissions and the persistence decision.

## Editing and image documents

`PhotoEditor` has separate completion forms: returning flattened `SBJResourceContent` or a `PhotoEditResult` recipe. The recipe preserves the source image and its current geometry, color, and markup state. `PhotoMenu` can work with a writable resource binding or a deferred `SBJResourceSource` that loads/saves an image on demand. An import source can be provided through `PhotoMenuImportSource`.

`SBJImageDocument` uses the `.sbjimage` package extension. Its original source and edit recipe are authoritative; generated thumbnails and rendered derivatives are caches. Use `RenderCache` to choose which derivatives to persist. Read APIs distinguish a cached image from permission to render a missing cache; do not assume a thumbnail exists simply because the document exists. Apps need register `.sbjimage` as a document type only when offering it as a standalone file format. See [ImageDocument](Documentation/ImageDocument.md) for the package format, caching and markup behavior.

## Movie posters and thumbnail caches

For movies, `getPosterFrame(from:at:)` chooses an explicit video frame when a time is supplied, otherwise it follows the selected embedded-poster fallback policy. `nil` timestamp is **not** frame zero. `hasPosterFrame` checks for the presence of embedded artwork metadata without decoding it. Embedded poster modifications are separate from a client's stored frame timestamp; see [MovieViewer poster workflows](Documentation/MovieViewerPosterWorkflows.md).

`PosterFrameCache` coalesces simultaneous requests for the same URL/time/revision, caches missing images as negative results, and invalidates revisions when embedded artwork changes. Negative and nonfinite times represent invalid frame requests: nonfinite times are normalized to the negative-time sentinel in cache keys, and invalid times are never submitted for extraction. Clients must call the appropriate invalidation method when source content or poster selections change. The cache avoids repopulating invalidated keys after an outstanding request completes.

`MovieFolderJoiner` creates a new chaptered QuickTime movie from the immediate movie children of a user-selected folder without modifying source files. The output folder must be writable. `MovieJoinCoordinator` provides observable join progress and error state for UI clients. Movie joining depends on the availability of supported AVFoundation exports and the file types in the selected folder.

## Supported platforms

The package declares macOS 14, iOS/Mac Catalyst 17, watchOS 10, visionOS 1, and tvOS 17 as minimums. Features requiring AVFoundation, PhotoKit, PencilKit, native image adapters, or particular SwiftUI controls are platform-conditioned. For example, watchOS does not support movie-frame extraction, and markup editing is not available through the macOS editor. A successful package build does not imply every media workflow is available on every destination.

## Responsibilities and limitations

- Keep security-scoped permissions valid while accessing user-selected files. Do not assume that retaining a URL retains access.
- Choose whether the host stores a flattened image, an edit recipe, or an `SBJImageDocument`; those representations have different persistence semantics.
- Keep photo-library authorization, camera capture, UI presentation and document storage distinct. `SBJImaging` integrates with those services but does not own every lifecycle.
- Generated images, movie exports, and embedded artwork can be costly or fail due to codec/permission constraints. Handle the throwing or result-valued APIs explicitly.
- Keep domain meaning in `SBJLocalization` and structural metadata in `SBJStructure`; media-specific composition, geometry and presentation belong here.

## Future capabilities

The image-document format preserves non-identity perspective and skew values but does not yet render those transformations. Color adjustment and markup support can expand without converting the image-document package into an edit-history format. These are design directions, not promises of currently implemented behavior.
