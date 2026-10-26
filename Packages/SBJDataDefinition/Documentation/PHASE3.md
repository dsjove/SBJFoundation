# Phase 3: designated initializer construction and source export

`@SBJStructure` synthesizes `sbjDefaultValue()` for types with a unique `@SBJDesignatedInit`. Parameters with Swift defaults are omitted so that the initializer owns its defaults; required parameters use `SBJDefaultValue.value(for:)`. If any required parameter has no default factory, construction returns nil. Handwritten defaults remain possible only when genuinely domain-specific construction is necessary.

`SBJStructured` already supplies `sbjSwiftExpression` via `sbjSwiftInitializerParameters` synthesized by `@SBJDesignatedInit`; the duplicate `UnitValue` implementation has been removed. Swift expression generation still requires that the mapped properties match initializer assignments.

This phase intentionally removes the custom unit source-generation and default implementations, rather than adding adapters.
