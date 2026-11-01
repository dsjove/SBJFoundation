# SBJFoundation editor organization

- `Sources/SBJFoundation/SBJStructure/` contains the SwiftUI editor runtime, controls, descriptors, bindings, previews, and editor-only public annotations.
- `Sources/SBJStructuredEditorMacros/` provides the `@SBJEditable` umbrella macro and editor annotations.
- The macro target imports `SBJStructureMacroSupport` from the SBJDataDefinition package to reuse structural generation without copying its implementation.
- `Tests/SBJFoundationTests/SBJStructure/` contains editor and integration tests.

The structural model, validation, search, and `@SBJStructure` are owned by SBJDataDefinition; no editor code moves into that package.
