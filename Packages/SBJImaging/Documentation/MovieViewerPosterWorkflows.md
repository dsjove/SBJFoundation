# MovieViewer poster workflows

`MovieViewerOptions` defaults to `setPoster: true`, `colorEdits: true`,
`posterEdits: true`. The last `MediaOpenRequest` initializer argument is
`setPoster: MoviePosterHandler? = nil`, which receives `(TimeInterval, CGImage)`.
`false` means the owner handled the selected image and does **not** want the
movie artwork updated. `true` means embed the edited full-resolution image in
movie metadata. With no handler, the viewer embeds the image.

The source is extracted at original resolution before presenting the optional
editor. The editor receives a `PhotoEditResult` whose color adjustment state
is initialized from MovieViewer's playback controls. Canceling the editor
stops the operation without invoking the owner or changing the movie.

## Integrations (the app sources are not included in SBJFoundation)

Casting selection:

```swift
MediaOpenRequest(
    title: title, file: file,
    options: .init(setPoster: true, colorEdits: true, posterEdits: false),
    setPoster: { time, image in
        // Save the selected casting timestamp/image in the app's model.
        // No change to the movie's embedded artwork.
        await persistCastingPoster(time: time, image: image)
        return false
    }
)
```

Movie selection:

```swift
MediaOpenRequest(
    title: title, file: file,
    options: .init(setPoster: true, colorEdits: true, posterEdits: true),
    setPoster: { time, image in
        // Optional app bookkeeping; SBJImaging embeds artwork after true.
        return true
    }
)
```

The closures are examples; `persistCastingPoster` belongs to the app and
must be connected to its actual storage implementation.

## Cross-platform design

The PhotoViewer, PhotoEditor and PhotoMenu UI types are each implemented once
in a common SwiftUI source file, with narrowly scoped compile-time branches for
AppKit/UIKit image adapters, native pasteboards, modal presentation, and iOS
PencilKit markup. The geometry model and image renderer are shared.

Markup editing is still unavailable on macOS; the unified PhotoEditor prevents
completion over markup it cannot safely render. Verify compilation and user
interactions on both Apple platforms.
