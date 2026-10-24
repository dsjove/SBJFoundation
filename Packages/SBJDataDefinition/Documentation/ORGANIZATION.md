# SBJDataDefinition source organization

- `Sources/SBJDataDefinition/` defines structural runtime protocols, metadata, validation, search, encoding, and public data annotations.
- `Sources/SBJDataDefinitionMacros/` is the compiler plugin for `@SBJStructure` and data annotations.
- `Sources/SBJStructureMacroSupport/` contains reusable compiler-side structural syntax analysis and generation, shared with the SBJStructuredEditor macro plugin. Higher-level macro packages compose generation layers using `SBJMacroGenerationLayer`. Structural declarations and conformances are always generated; editor descriptor emission and editor conformances belong to the editor layer, not this target. This target is compiler-only, not a runtime library.
- `Tests/SBJDataDefinitionTests/` tests the runtime and data-only macros.

SBJDataDefinition depends on SBJLocalization, not SBJFoundation. Its public data annotations should not require importing an editor module.

Structural traversal descriptors expose both `sourceName` (the Swift property identifier used for stable identity and programmatic traversal) and `displayName` (the human-readable default label). Consumers such as editors and generated data-definition documents should use the former for keys and the latter for presentation. Traversal and structural metadata are UI-independent; a PDF documentation renderer can consume them without depending on SBJStructuredEditor.

The `SBJStructuralTraversal.definition(of:)` and `visitDefinition(of:_:)` APIs provide instance-free type definitions including immutable properties through `SBJStructured.sbjProperties`. `schema(of:)` and `visitValues(in:_:)` are specifically writable-property traversals for `SBJMutableStructure`. Documentation generators should use `definition` so they do not silently omit `let` properties. Both views use source names for stable identity and display names for labels.

- `Sources/SBJDataDefinition/Codables/{Units,Fonts,Colors}`: typed model implementations and structural adapters.
- `Sources/SBJDataDefinition/Samples/Recipe`: debug-only integration sample exercising annotations and enum payloads.
