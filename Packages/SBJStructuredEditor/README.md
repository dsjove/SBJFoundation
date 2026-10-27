# SBJStructuredEditor

`SBJStructuredEditor` provides SwiftUI editing for mutable structured models described by `SBJDataDefinition`. It uses typed property metadata to construct editor rows, perform bound mutations, present validation, and navigate nested structures.

## Dependencies and ownership

- `SBJDataDefinition` supplies `@SBJStructure`, structural metadata, defaults, validation, and collection identity/traversal rules.
- `SBJLocalization` supplies localized names and textual presentation.
- `SBJUIVocabulary` supplies shared controls and field-presentation primitives.
- `SBJFileResources` and `SBJHelp` support bundled editor help.

This package has no compiler macro target. Applications define their models with DataDefinition and configure editing through the public editor views and registry.

## Editor composition

`SBJEditorView` accepts a binding to an `SBJMutableStructure` and an `SBJEditorPresentationModel`. `SBJStructuralEditorView` exposes the same structural editor. `SBJCodableEditorCore` and `SBJCodableEditor` provide additional editor compositions.

`SBJEditorRegistry` supports registered controls, construction overrides, per-property presentation, and binding overrides. An exact-type registered creator takes precedence over DataDefinition default construction. Collection-aware array creation may decline insertion when its candidate domain is exhausted.

## Properties and traversal

Writable stored properties are projected from DataDefinition's typed `SBJMutableStructure` descriptors. Writable computed properties explicitly annotated `@SBJPresentationProperty` are projected separately as presentation-only fields. Immutable properties remain part of the structural model but are not rendered as editable fields.

The editor uses logical item identifiers and live collection locations independently, so array actions target the current element after movement. Duplicate or missing identifiers use positional identity. Sets use draft-and-commit editing to avoid accidental collisions.

## Controls and creation

The value editor dispatches to controls for textual, numeric, boolean, date, URL, color, enum, collection, optional, and unit values. `UnitValue`, `MixedUnitValue`, and `PairedUnitValue` use atomic editing controls.

Arrays use collection-aware element creation when available. Sets whose elements are `CaseIterable & Hashable` use their first unused case; dictionaries with `CaseIterable & Hashable` keys use the first unused key and construct its associated value through the registry. Insertion is unavailable after exhaustion or when a required value cannot be created. For other types, set and dictionary insertion uses ordinary defaults subject to uniqueness checks.

The editor supports structural search, changed-only and empty-content filtering, disclosure controls, and model validation. Search-driven expansion is an editor presentation rule, while structural matching lives in DataDefinition.

## Help and previews

`SBJBundledContentReference.structuredEditorCore` and `.structuredEditorSearch` identify bundled help fragments. Applications can register them with `SBJHelpConfiguration.includeStructuredEditorHelp()`.

The preview target uses DataDefinition's debug-only `SBJStructureSampleModel` from `Codables/Sample`. Preview examples include custom registry controls and structural field editing.

On tvOS and watchOS, shared model definitions remain available through DataDefinition; interactive editor surfaces depend on platform availability.

## Tests and architecture

Tests cover construction precedence and exhaustion, property binding, collection identities and mutations, structural and enum traversal, text and unit control dispatch, and filter behavior. Layout, focus, accessibility, menus, and confirmation dialogs also require UI testing on supported devices.

See `Documentation/ARCHITECTURE.md`, `Documentation/PUBLIC_API_AND_CONSTRUCTION.md`, `Documentation/TRAVERSAL_AND_RENDERING.md`, and `Documentation/CONTROLS_AND_TEST_COVERAGE.md` for detailed contracts.
