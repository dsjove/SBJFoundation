# MovieViewer poster workflows

`MovieViewerOptions` defaults to frame selection enabled, embedded-artwork editing disabled,
and color adjustments and image tools enabled. The last `MediaOpenRequest` initializer argument is
`setPoster: MoviePosterHandler? = nil`, which receives a typed `MoviePosterAction`.
`false` means the owner handled the selected image and does **not** want the
movie artwork updated. `true` means embed the edited full-resolution image in
movie metadata. With no handler, the viewer embeds the image.

The source is extracted at original resolution before presenting the optional
editor. The editor receives a `PhotoEditResult` whose color adjustment state
is initialized from MovieViewer's playback controls. Canceling the editor
stops the operation without invoking the owner or changing the movie.

## Integrations

`MovieViewerOptions` has independent `allowsFrameSelection` and
`allowsEmbeddedPosterEditing` switches. Both may be true. `allowsColorAdjustments`
and `allowsImageTools` control the other editor features.

When both poster capabilities are enabled, use one `MediaOpenRequest` and one
`MoviePosterHandler`. Actions are `.selectFrame(time:image:)`, `.clearFrame`,
`.embedArtwork(image)`, and `.clearArtwork`. Separate clear cases ensure
clearing a sidecar timestamp never deletes the embedded artwork. Returning
`false` means the application handled persistence; `true` lets the viewer
perform the embedded-artwork operation.

## Cross-platform design

The PhotoViewer, PhotoEditor and PhotoMenu UI types are each implemented once
in a common SwiftUI source file, with narrowly scoped compile-time branches for
AppKit/UIKit image adapters, native pasteboards, modal presentation, and iOS
PencilKit markup. The geometry model and image renderer are shared.

Markup editing is still unavailable on macOS; the unified PhotoEditor prevents
completion over markup it cannot safely render. Verify compilation and user
interactions on both Apple platforms.

## Combined-control editor behavior and symbols

When both `allowsFrameSelection` and `allowsEmbeddedPosterEditing` are enabled,
the sidecar-frame action selects the current timestamp directly without opening
`PhotoEditor`; the optional editor remains part of the embedded-photo `PhotoMenu`
workflow. A timestamp-only viewer continues to offer the editor when
`allowsImageTools` is enabled.

The timestamp actions use `photo.stack` (select current frame) and `photo.slash`
(clear selection); the embedded-photo menu uses `person.crop.artframe`.
