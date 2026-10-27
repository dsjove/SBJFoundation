# Package organization and dependencies

- `Sources/SBJDataDefinition/Annotations` defines the public structural, validation, and presentation annotations.
- `Sources/SBJDataDefinition/SBJStructure/Public` provides structural metadata, content, comparison, validation, default construction, and referenced-content APIs.
- `Sources/SBJDataDefinition/SBJStructure/SwiftEncoder` provides Swift source export.
- `Sources/SBJDataDefinition/Search` contains UI-independent structural search and filtering.
- `Sources/SBJDataDefinition/Codables` contains concrete reusable Codable types and their presentation/structural adapters. Its `Foundation` folder contains extensions on Foundation types; `Units`, `Colors`, and `Fonts` contain value families; `Sample` contains a DEBUG-only comprehensive model fixture.
- `Sources/SBJDataDefinitionMacros` provides the compiler macro plugin.
- `Sources/SBJStructureMacroSupport` provides compiler-side SwiftSyntax analysis and code-generation helpers shared with editor macro implementations; it is not a runtime app dependency.
- `Tests/SBJDataDefinitionTests` exercises macros, metadata, validation, units, search, traversal, collections, defaults, and source encoding.

`SBJDataDefinition` depends on `SBJLocalization` for nomenclature and text search. It does not import SwiftUI or depend on `SBJStructuredEditor`. The editor consumes structural metadata to implement views, bindings, navigation, and disclosure. `SBJPropertyInfo` is defined in SBJLocalization.

Metadata uses `sourceName` for programmatic identity and `displayName` for human-facing presentation. `SBJStructuralTraversal.definition(of:)` includes immutable properties; writable-value traversal is restricted to properties that can be edited.
