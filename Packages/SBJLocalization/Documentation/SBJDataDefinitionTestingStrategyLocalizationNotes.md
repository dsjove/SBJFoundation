# SBJDataDefinition — TestingStrategy localization-related notes

## Package responsibilities

- **SBJDataDefinition:** generated structural members and annotations, validation, equality, defaults, traversal, collection changes and source encoding.
- **SBJLocalization:** string transformation rules, optional/empty presentation handling, accessibility behavior and metadata decisions. Do not test duplicated literal titles.
- **SBJUIVocabulary:** field-sizing and menu-selection policy, disabled/invalid decisions and meaningful UI state policy. Prefer pure policies over snapshots.
- **SBJUnits:** Codable round trips preserving unit choices, conversion mathematics, invariant checks and conversion-state workflow.
- **SBJFileResources:** content integrity, resource resolution, filename collision handling, security-scope and failure behavior.
- **SBJDocuments:** document/library persistence behavior, ordering and error recovery.
- **SBJHelp:** content resolution, templating precedence and presenter dispatch; do not retest Foundation's string replacement.
- **SBJCamera:** encoded capture representation and capture behavior; avoid tests limited to stored properties.
- **SBJStructuredEditor:** tests its own parsing, structural projection, model-driven editing, validation propagation, traversal, and nontrivial state transitions.
- **SBJFoundation:** integrated image/attachment/structured-editor interactions and platform behavior not owned by the smaller modules.

