# SBJStructuredEditor

SwiftUI editors for structured data models defined by `SBJDataDefinition`.

## Using the editor

Add `SBJStructuredEditor` to the application target and import it where you present or configure structured editors. The module provides the editor controls, traversal, search, navigation, field presentation, and editor-specific annotations such as `@SBJEditable`.

Editor annotations are expanded by `SBJStructuredEditorMacros`. Structural metadata generation support is shared with `SBJDataDefinition` through `SBJStructureMacroSupport`. The `SBJEditorGeneration` layer composes editor fields and conformances onto unconditional structural generation; data-only models do not generate editor declarations.

## Dependencies

- `SBJDataDefinition` for model metadata and structural operations
- `SBJLocalization` for labels, metadata, and symbols
- `SBJUIVocabulary` for shared controls and field presentation
- `SBJUnits` for unit-value editor integration
- `SBJHelp` and `SBJFileResources` for bundled editor help content

## Testing

The test target covers editor behavior and macro expansions. Prefer tests of behavior and contracts over simple accessors or string copying.

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

On tvOS and watchOS, all editor annotation macros and model metadata APIs are
available. The interactive SwiftUI editor and search presentations are excluded.

Stored-property editor traversal uses a single structural-schema lookup per field projection for both `@SBJStructure` and `@SBJEditable` models. Source names and structural locations define identities; presentation labels never do. Computed editor-only fields retain separate editor-local identities. This keeps editor navigation consistent with instance-free schema traversal and other consumers of `SBJDataDefinition`.

## Structural property projection

`SBJStructuralFieldProjection` is the editor's internal adapter from the typed
`SBJMutableStructure.sbjMutableProperties` descriptors to field descriptors.
The adapter uses `SBJTypedStructuralPropertyVisitor` to preserve the property's
concrete Codable type and writable key path. Only writable structural fields are
projected; immutable schema properties remain available through DataDefinition's
`definition(of:)` traversal. Explicit editor annotations continue to be supplied
by `@SBJEditable` and are separate from the underlying structural schema.


### Automatic structural editing

The editor renders writable properties from any `@SBJStructure` model through
`SBJDataDefinition`'s typed structural descriptors, including nested structural
values and collections. `@SBJEditable` is optional for automatic structural
editing; it provides explicit editor presentation annotations and computed editor
fields. Editor capability diagnostics use the same structural fallback as the
renderer. Immutable properties remain in the structural definition but are not
rendered as editable fields.

Structural models can use `SBJEditField(root:keyPath:)` without adopting `SBJSwiftUIEditable`. Editor-only appearance hints are applied only when the root also conforms to `SBJSwiftUIEditable`.

### Collection editing

Array rows use the shared structural collection traversal for ordering, identity, and location. Bound rows project live, bounds-checked mutation capabilities from `SBJDataDefinition` into remove and reorder actions. Move controls honor the array's `reorderable` constraint and are suppressed when a filtered subset is being displayed; read-only traversal never provides mutation controls.

### Collection element actions

Array, set, and dictionary entries do not acquire independent property-info metadata from their containing property. Their removal control occupies the shared trailing information gutter, aligned with the collection header's property-info control. Array move controls remain adjacent to the element value. The property-info sheet prefixes its title with `SBJPropertyInfo.symbol` when provided, falling back to the standard information symbol. Collection removal is a destructive, confirmation-gated action: Cancel leaves the collection unchanged, and only confirming Remove invokes the mutation.
