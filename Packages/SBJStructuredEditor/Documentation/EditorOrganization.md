# Source organization

`SBJStructuredEditor` organizes client-facing editing behavior under `Editor/`:

- `Public/`: entry points, registry, presentation state, navigation, and feature vocabulary.
- `Automatic/`: maps `SBJStructure` metadata into editable rows and live bindings.
- `Controls/`: input controls, value drafts, and collection editors.
- `Interaction/`: search expansion and collection actions.
- `Layout/`: field geometry and accessibility presentation.
- `Support/`: internal typed-binding utilities.
- `Preview/`: example compositions and preview support.

Tests mirror these responsibilities. `SBJStructure` owns model metadata, default construction, structural traversal and invariants; the editor owns only UI-specific adapters. The package does not contain a macro target.
