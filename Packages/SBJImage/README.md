# SBJImage

Image references, non-destructive image documents, photo geometry, rendering, import/export, viewer, and editor UI.

## Dependency

From the SBJFoundation workspace use `.package(path: "Packages/SBJImage")` and depend on `.product(name: "SBJImage", package: "SBJImage")`. Import `SBJImage` to use the image APIs.

The bundled Image Edit and Image View help resources are owned by this package, as are its focused tests. Existing photo-editor `@AppStorage` keys intentionally retain their `SBJFoundation` prefix to preserve users' preferences.

See [IMAGE_DOCUMENT.md](Documentation/IMAGE_DOCUMENT.md) for the document format.
