# SBJStructuredEditor

The package interface for editing `SBJDataDefinition` models with shared UI vocabulary and unit controls.

## Current availability

This package currently contains a scaffold target. The functional structured editor, public editor annotations and editor macro plugin remain in `SBJFoundation`. **Importing `SBJStructuredEditor` alone does not yet provide the complete editor UI.** Refer to the [Foundation editor guide](../../Documentation/Editor/EDITOR_GUIDE.md) for the currently available API and examples.

## Dependencies

`SBJDataDefinition`, `SBJUIVocabulary`, `SBJLocalization` and `SBJUnits`. Editor-specific UI and generated conformances belong at this layer, not in the data-model or unit packages.

## Tests

The scaffold has no meaningful runtime behavior to test yet. When the editor implementation is provided by this package, cover user-visible state transitions, navigation, mutation, validation and macro integration; avoid accessor-only and copy-only tests.
