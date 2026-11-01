# Traversal and rendering

`SBJStructuredEditor` projects structured values into editor rows and renders those rows using typed controls. Structural metadata and collection ordering are supplied by `SBJDataDefinition`; the editor owns bindings, row identities, editing controls, disclosure and rendering.

## Traversal contexts

`SBJEditTraversalContext` carries the visual depth, stable logical item identifier, current index path, navigation path and branch state. Collection traversal uses `collectionChild(identifier:location:title:)` to create descendant contexts. The collection item identifier and current location are distinct: moving an identified element can change its index path without changing the row's logical identity.

A descendant inherits search criteria; transient row status, placement and disclosure state reset through `branch.child`.

## Traversal and projection

`SBJEditorValueTraversal` performs editor traversal for structures, associated-value enums, optionals and collections. Typed editor values are atomic, so their internal structure is not traversed for rendering. Registered custom editors are atomic for bound traversal.

Collection ordering, titles and identity policies come from `SBJCollectionTraversal` in `SBJDataDefinition`. A read-only projection describes the value tree; a bound projection retains live bindings. Array bindings resolve stable identifiers against current contents, with positional identity when configured identifiers are duplicated or unavailable. Set entry editing uses draft-and-commit semantics to preserve uniqueness checks.

`SBJEditorTraversalNode` separates node metadata, inclusion criteria, deferred child production and optional row rendering. Structural field and object projections build the editor's flat row snapshot from these nodes.

## Rendering

`SBJValueEditor` dispatches values to type-specific controls, collection editors, optional editors or supported custom editors. Controls manage SwiftUI presentation; model validation, type information and structural collection policies remain in `SBJDataDefinition`.

## Verification

The traversal-context tests check logical identity independently of current location and confirm that child contexts inherit search criteria without inheriting transient row state. Tests for collection behavior, structural projections and filter handling live under `Tests/SBJStructuredEditorTests`.
