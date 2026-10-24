# SBJStructuredEditor

SwiftUI editors for structured data models defined by `SBJDataDefinition`.

## Using the editor

Add `SBJStructuredEditor` to the application target and import it where you present or configure structured editors. The module provides the editor controls, traversal, search, navigation, field presentation, and editor-specific annotations such as `@SBJStructure`.

`SBJStructuredEditor` contains no compiler plugin or annotation macros. `SBJDataDefinition` owns `@SBJStructure`, `@SBJPresentation…` and compiler generation. The editor projects generated typed metadata into SwiftUI controls.

## Dependencies

- `SBJDataDefinition` for model metadata and structural operations
- `SBJLocalization` for labels, metadata, and symbols
- `SBJUIVocabulary` for shared controls and field presentation
- `SBJDataDefinition` for unit-value models and structural metadata
- `SBJHelp` and `SBJFileResources` for bundled editor help content

## Testing

The test target covers editor behavior, structural field projection, enum editing, and presentation metadata. Compiler macro expansion and layered generation tests belong to `SBJDataDefinition`.

## Built-in help

`SBJBundledContentReference.structuredEditorCore` and `.structuredEditorSearch` identify the HTML resources bundled by `SBJStructuredEditor`. Applications can register both through `SBJHelpConfiguration.includeStructuredEditorHelp()` and present Help with the standard `SBJHelp` controls.

## Snapshot and collection utilities

`sbjCodableCopy()` and `sbjEncodedIsDifferent(from:)` support snapshotting and comparisons used by editor state. `sbjReplace(_:with:)` handles set replacements without losing an item on an existing-value collision. The set operation is kept in `Set+SBJReplace.swift`, separate from the Codable helpers.

## Embedding editor Help in an application

The editor bundles its core and search help fragments. An application's shared
`SBJHelpConfiguration` can include them by calling `includeStructuredEditorHelp()`.
This registers the `SBJ_STRUCTURE_EDITOR_CORE_HELP` and
`SBJ_STRUCTURE_EDITOR_SEARCH_HELP` template tokens for the Help renderer, using
the editor package's own resource bundle. App-owned Help pages may embed those
fragments without copying their HTML.

On tvOS and watchOS, DataDefinition annotations and model metadata remain available. The interactive SwiftUI editor and search presentations are excluded.

Stored-property editor traversal uses a single structural-schema lookup per field projection for `@SBJStructure` models. Source names and structural locations define identities; presentation labels never do. Computed editor-only fields retain separate editor-local identities. This keeps editor navigation consistent with instance-free schema traversal and other consumers of `SBJDataDefinition`.

## Structural property projection

`SBJStructuralFieldProjection` is the editor's internal adapter from the typed
`SBJMutableStructure.sbjMutableProperties` descriptors to field descriptors.
The adapter uses `SBJTypedStructuralPropertyVisitor` to preserve the property's
concrete Codable type and writable key path. Only writable structural fields are
projected; immutable schema properties remain available through DataDefinition's
`definition(of:)` traversal. Presentation annotations are supplied by `SBJDataDefinition`, not by this package.


### Automatic structural editing

The editor renders writable properties from any `@SBJStructure` model through
`SBJDataDefinition`'s typed structural descriptors, including nested structural
values and collections. `@SBJStructure` generates the structural schema and optional presentation-only
computed field descriptors. Editor capability diagnostics use the same structural fallback as the
renderer. Immutable properties remain in the structural definition but are not
rendered as editable fields.

Models conforming to `SBJMutableStructure` can use `SBJEditField(root:keyPath:)`. Presentation hints are supplied through DataDefinition metadata.

### Collection editing

Array rows use the shared structural collection traversal for ordering, identity, and location. Bound rows project live, bounds-checked mutation capabilities from `SBJDataDefinition` into remove and reorder actions. Move controls honor the array's `reorderable` constraint and are suppressed when a filtered subset is being displayed; read-only traversal never provides mutation controls.

### Collection element actions

Array, set, and dictionary entries do not acquire independent property-info metadata from their containing property. Their removal control occupies the shared trailing information gutter, aligned with the collection header's property-info control. Array move controls remain adjacent to the element value. The property-info sheet prefixes its title with `SBJPropertyInfo.symbol` when provided, falling back to the standard information symbol. Collection removal is a destructive, confirmation-gated action: Cancel leaves the collection unchanged, and only confirming Remove invokes the mutation.

Both `SBJEditorView(value:presentationModel:)` and `SBJStructuralEditorView(value:presentationModel:)` accept `SBJMutableStructure`; they are aliases of the same metadata-driven editor.

## Structural presentation metadata

For models annotated with `@SBJStructure`, the automatic structural field
projection honors presentation hints supplied by `SBJDataDefinition`:
`@SBJPresentationExclude` removes a field from automatic rendering (not from
structural metadata or validation); `@SBJPresentationDisclosure` controls the
initial disclosure state; text and collection hints are interpreted from the
property metadata by the existing field editor.

Writable computed properties explicitly marked `@SBJPresentationProperty` are
projected from `SBJMutableStructure.sbjPresentationProperties`. They remain
presentation-only and do not acquire stored-property identities or schema
validation. The editor constructs their fields via typed visitation, separate
from the structural-property visitor.

### DataDefinition associated-enum dispatch

The automatic editor now obtains case selection, payload traversal, issue
collection, and case switching for `SBJStructuredEnum` directly from
`sbjAssociatedCases`. `SBJEditorEnumCase` remains a SwiftUI-side adapter; it is
not generated for types annotated only with `@SBJStructure`. Transitional
### Canonical debug Recipe fixture

The broad integration fixture is under `Packages/SBJDataDefinition/Sources/SBJDataDefinition/Samples/Recipe/`.
It is compiled only for `DEBUG` configurations and is used by the structured
editor previews and the `SBJStructureSampleModelTests` suite. The same Recipe
model includes nested enums, associated payload variants (unlabeled, labeled,
optional, collections), repeated enum cases, recursive stages, arrays, sets,
dictionaries, and scalar editor coverage. The old independent enum stress
model/preview has been removed. Compile-time generic-conformance checks live
in `SBJRecipeCompileTimeContractTests`.
