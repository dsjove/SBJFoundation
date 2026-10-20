# SBJUnits

`SBJUnits` supplies a typed, Codable unit vocabulary and reusable conversion controls.

## Why this exists: the Codable gap

Foundation’s `Dimension` and `Measurement` perform conversions but do not provide the domain-specific, stable, strongly typed Codable nomenclature our persisted models require. `UnitType` and the enums in `Nomenclature` define those identifiers, and `UnitValue<Unit>` encodes the amount *and its chosen unit*, rather than normalizing away the original unit. Conversion uses Foundation measurements. Do not change the encoded representation during package extraction.

## Organization

- `Nomenclature`: unit protocols, categories, and built-in unit names and string presentations
- `Model`: `UnitValue`, editing policy, and conversion state
- `Validation`: unit-specific structural invariant checks
- `Controls`: reusable value and conversion UI, **not** structured-editor implementation
- `Presentation`: shared unit symbols and help configuration

## Dependencies and editor boundary

`SBJUnits` depends on `SBJDataDefinition`, `SBJLocalization`, `SBJUIVocabulary`, and `SBJHelp`, **not** the editor. Model annotations use `@SBJStructure` rather than `@SBJEditable`.

`SBJStructure/Editor/Controls/Values/SBJUnitValueEditor.swift` stays with the editor and adapts the reusable `UnitValueControl` to editor bindings and dispatch. `SBJStructuredEditor` depends on `SBJUnits`.
