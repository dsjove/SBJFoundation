# SBJUnits

Strongly typed physical quantities and conversion UI with stable Codable representations.

## Why this package exists

Foundation's `Dimension`/`Measurement` support arithmetic and conversion, but do not by themselves define an application's stable, type-safe persisted vocabulary of supported units. `UnitValue<Unit>` stores both the numeric amount and the selected unit, so round-tripping a document preserves the user's choice of unit. Conversion uses Foundation measurement semantics.

```swift
import SBJUnits

let length = UnitValue(12, unit: LengthUnit.inch)
```

## Model and nomenclature

Models use structural metadata through `@SBJStructure`, without depending on editor annotations. Each model owns a `+Nomenclature.swift` extension for its `StringPresentable` conformance and any genuinely helpful named `fooInfo: SBJPropertyInfo` declarations. String-backed enum descriptions use the default raw-value un-camel-casing. Explicit titles are for exceptions, not for repeating the raw values. Each built-in physical unit has an abbreviation.

The source is organized by model; reusable controls, conversion state and unit-specific validation are separate from structured-editor adapters.

## Dependencies

`SBJDataDefinition`, `SBJLocalization`, `SBJUIVocabulary` and `SBJHelp`. The structured editor may depend on `SBJUnits`, but `SBJUnits` does not depend on the editor.

## Tests

Cover Codable round trips that preserve chosen units, conversion math, validation and significant conversion workflow behavior. Do not test simple stored properties or duplicate descriptions of raw-value cases.
