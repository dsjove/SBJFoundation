# SBJDataDefinition source organization

- `Sources/SBJDataDefinition/` defines structural runtime protocols, metadata, validation, search, encoding, and public data annotations.
- `Sources/SBJDataDefinitionMacros/` is the compiler plugin for `@SBJStructure` and data annotations.
- `Sources/SBJStructureMacroSupport/` contains reusable compiler-side structural syntax analysis and generation, shared with the SBJFoundation editor macro plugin. It is not a runtime library.
- `Tests/SBJDataDefinitionTests/` tests the runtime and data-only macros.

SBJDataDefinition depends on SBJLocalization, not SBJFoundation. Its public data annotations should not require importing an editor module.
