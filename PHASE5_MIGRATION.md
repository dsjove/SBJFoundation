# Phase 5 framework migration

Framework changes only. The Photo Message, TODO, Pieces, and Meals app repositories were not available in this turn and have **not** been migrated or compiled.

- `Accessible` removed. `AccessibleItem` is now a standalone assembled value.
- `SBJTextPresentable` replaces `StringPresentable` (breaking rename, no alias). It continues to provide display descriptions, abbreviation, multiline description, and an accessibility-value default through `AccessibilityValues`.
- `AccessibleSymbol` retains symbol-specific responsibilities, without inheriting the removed accessibility contract. Consumers obtain the assembled `accessibility` item from `AccessibleSymbolItem`.
- Shared framework references, editor presentation, and tests updated to `SBJTextPresentable`.
- `SBJPropertyInfo` remains declaration metadata and `SBJStructured.accessibilityItem(for:)` continues to merge it with runtime accessibility.

Follow-up: migrate each app source and audit whether `SBJTextPresentable` should eventually be replaced by a richer localized text resource. The rename here intentionally does not create compatibility scaffolding.
