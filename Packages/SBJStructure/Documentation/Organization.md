# Source organization

- `Sources/SBJStructure/Annotations`: public structural and property macros.
- `Sources/SBJStructure/SBJStructure`: structural metadata, traversal, construction, validation adapters, and source exporting.
- `Sources/SBJStructure/Search`: structural search and Foundation adapters.
- `Sources/SBJStructure/Codables`: reusable Codable value types, protocol helpers, and Foundation utilities independent of `SBJStructured`.
- `Sources/SBJStructure/Samples`: example models for integration and macro coverage.
- `Sources/SBJStructureMacros`: compiler plugin.
- `Sources/SBJStructureMacroSupport`: shared SwiftSyntax generation support.

General domain semantic protocols, validation paths, and invariant primitives are owned by the sibling `SBJLocalization` package. Do not duplicate them here.
