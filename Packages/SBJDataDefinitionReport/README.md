# SBJDataDefinitionReport

Phase 9A provides an instance-free catalog of compiled structural declarations.
The package has no dependency on SBJStructuredEditor and does not create model instances.

Use `SBJDefinitionCatalog(Recipe.self)` for a single structured root. Use
`SBJDefinitionCatalog.Builder` to register multiple structs and enum definitions;
`add` has overloads for `SBJStructured`, `SBJEnumCaseIdentifiable`, and
`SBJStructuredEnum`. Build once to receive a deterministic, deduplicated catalog.

Type ordering is alphabetical by default. Property and case ordering preserve
source declaration order. All three are independently configurable.

The schema presently exposes stored structural properties, their actual Swift
identifiers and declared types, constraint and presentation hints, and PropertyInfo.
Associated-value enums expose payload names and types via typed metadata dispatch.

## Explicitly deferred until declaration metadata is extended

Automatic transitive discovery of referenced types, raw-value enum literals,
static/computed PropertyInfo-only declaration inventory, and fully qualified
references through Optional/collection wrappers are not available from current
DataDefinition type metadata. They are *not* inferred from constructed values.
These capabilities must be added to DataDefinition macro output before marking
Phase 9A complete. No SwiftUI viewer or PDF generator is provided in this package.
