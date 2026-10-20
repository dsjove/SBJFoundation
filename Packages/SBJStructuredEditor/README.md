# SBJStructuredEditor

SwiftUI editors for structured data models defined by `SBJDataDefinition`.

## Using the editor

Add `SBJStructuredEditor` to the application target and import it where you present or configure structured editors. The module provides the editor controls, traversal, search, navigation, field presentation, and editor-specific annotations such as `@SBJEditable`.

Editor annotations are expanded by `SBJStructuredEditorMacros`. Structural metadata generation support is shared with `SBJDataDefinition` through `SBJStructureMacroSupport`.

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
