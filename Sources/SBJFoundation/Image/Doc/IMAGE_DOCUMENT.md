# SBJ Image Document

`SBJImageDocument` is a self-contained, non-destructive image package. It stores the immutable encoded source image plus the current edit state. It is deliberately **not** an edit history.

## Package type

`SBJImageDocument` does not import or export a document type from the reusable framework. For in-process resource content it resolves `.sbjimage` with `UTType(filenameExtension:conformingTo:)`, specifying `public.package`. This yields the registered type in an app that exports the extension, or a local dynamic type in apps that merely embed/read/write the format.

- Framework filename extension constant: `.sbjimage`
- Framework package schema identifier: `SBJImageDocument.formatIdentifier`
- In-process content type: `SBJImageDocument.contentType`
- System document registration: optional and owned by an app that exposes `.sbjimage` as a standalone document

## Layout

```text
Example.sbjimage/
    manifest.json
    source/
        original.<source-extension>
    edits/
        geometry.json
        color.json
        markup.data            # optional
    Rendered/
        thumbnail.<image-ext>  # optional bounded thumbnail cache
        full.<image-ext>       # optional full rendered cache
```

The source, optional `CLLocation` metadata, and current edit state are authoritative document data. Location is persisted independently as `location.json`, preserving coordinate, altitude, accuracy, course, speed, and timestamp values. When a full rendered cache is persisted, the same location is also injected into that rendered image as GPS image metadata. Packages written before location support remain readable and simply expose `nil` location.

The source and current edit state are authoritative image content. Rendered derivatives are disposable caches selected by `SBJImageDocument.RenderCache`:

- `.thumbnail`: persist a bounded thumbnail derivative.
- `.rendered`: persist the full flattened edited image.
- `.all`: persist both derivatives.
- `[]`: persist no rendered derivatives.

The default is `.thumbnail`. A generated thumbnail is bounded to 512 pixels on its longest edge.

## Rendering roles

The package deliberately separates three jobs:

1. **Thumbnail providers** ask `SBJImageDocument.thumbnailURL(in:)` for the persisted thumbnail. If the document has none, the host provider chooses its own fallback behavior. Generated thumbnails have a maximum edge of 512 pixels and are encoded for compact storage (JPEG for opaque images, PNG when alpha is required).
2. **Quick Look / full preview consumers** ask `SBJImageDocument.renderedImage(at:renderIfNeeded:options:)` with an explicit cache-miss policy. Persisted rendered-cache lookup remains an implementation detail of that operation.
3. **Source fallback** is reserved for full rendering when the requested derivative cannot be produced; cache URL lookup itself does not fall back to the source.

Hosts can therefore trade package size for preview speed explicitly rather than having separate thumbnail policy semantics.

## `manifest.json`

The manifest identifies every component by path and content type. Readers should ignore JSON fields they do not recognize and should not assume that markup is PencilKit unless its declared content type says so.

The container currently publishes separate components for:

- source image
- geometry recipe
- color recipe
- optional markup
- render-cache options (`renderCache`)
- optional generated thumbnail component (`thumbnail`)
- optional full rendered component (`rendered`)

## Geometry

`geometry.json` is encoded from `PhotoEditGeometry` and currently describes:

- crop
- normalized placement
- magnification
- quarter-turn and fine rotation
- horizontal/vertical mirror
- perspective
- skew

Perspective and skew are reserved fields. The current framework preserves them but does not yet render non-identity perspective or skew.

Perspective uses four points in normalized source/composition space. Identity is the unit square:

```text
topLeft     = (0, 0)
topRight    = (1, 0)
bottomLeft  = (0, 1)
bottomRight = (1, 1)
```

Skew values are degrees. Identity is zero horizontal and vertical skew.

## Color

`color.json` is currently an empty `PhotoColorAdjustments` object. It remains a separate component so future color controls can be added without changing the package container shape.

## Markup

Markup is format-neutral at the package level. The manifest records:

- path
- content type identifier
- canvas width and height
- coordinate space

The current editor uses serialized PencilKit `PKDrawing` data and composition coordinates. Other markup encodings can be introduced later without changing the image-document container.

## Framework API roles

- `PhotoEditGeometry`: portable geometry state.
- `PhotoColorAdjustments`: portable color state; currently empty.
- `PhotoMarkup`: serialized markup plus coordinate metadata.
- `PhotoEditResult`: display name + description + current geometry + color + markup, usable entirely in memory and persisted by the image package.
- `PhotoEditor`: edits an image document and returns one atomically updated document.
- `SBJImageDocument.RenderCache`: option set containing `.thumbnail`, `.rendered`, and `.all`. Use `SBJImageDocument(source:renderCache:)`; the default is `.thumbnail`.
- `SBJImageDocument.thumbnailURL(in:)`: cheap thumbnail-provider path that returns only the thumbnail cache already stored in the package, or `nil` when none is present. It does not render or fall back to the source image.
- `SBJImageDocument.thumbnailImage(at:renderIfNeeded:options:)` and `thumbnailImage(renderIfNeeded:options:)`: callers explicitly choose whether a missing thumbnail cache may be rendered or must fail fast.
- `SBJImageDocument.renderedImage(at:renderIfNeeded:options:)` and `renderedImage(renderIfNeeded:options:)`: callers explicitly choose whether a missing full-render cache may be rendered; source fallback is used only after an allowed render attempt fails.
- `SBJImageDocument`: owns source/edit/cache consistency internally rather than exposing those components for callers to coordinate.

`PhotoMenu` infers edit semantics from the bound resource. An ordinary image is edited destructively/in memory; an `SBJImageDocument` is reopened with its saved geometry, color state, and markup. Applications choose persistence semantics by what their resource binding stores. A binding that requires non-destructive images can normalize assigned images with `SBJResourceContent.preservingImageEdits`.

## System registration and presentation

`SBJImageDocument` is a framework-provided persistence/interchange format, not a document type that every host application must advertise. Host applications that merely embed image documents inside their own documents do **not** need to register `.sbjimage` as a standalone document type.

Embedded thumbnail presentation uses `SBJResourceContent.uiImage`, `SBJImageDocument.thumbnailImage(renderIfNeeded:options:)`, or `ImageReference.document`. Quick Look thumbnail providers can use `SBJImageDocument.thumbnailURL(in:)` for the persisted-cache-only URL path and choose their own fallback when it returns `nil`. Image-returning presentation APIs require an explicit `renderIfNeeded` choice. Full-size preview code uses `renderedImage(..., renderIfNeeded: ...)`, keeping persisted-cache lookup behind that API.
