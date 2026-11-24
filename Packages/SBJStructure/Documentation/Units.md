# Unit value models

`Codables/Units` supplies typed `UnitValue<Unit>`, unit conversion, measurement systems, and presentation metadata as reusable Codable models. Application code can use the conversion and Codable behavior independently of `@SBJStructure`; the structural adapters expose selected models to structured inspection and Swift source export.

Use `UnitValue<Unit>` to preserve an amount together with its unit, and `converted(to:)` to request a compatible representation. `UnitConversionModel` provides observable source and destination selections for clients that need a conversion workflow.

Domain validation is explicit. Unit-specific checks are supplied through `SBJInvariantCheck` extensions in this package, layered on the general invariant contracts owned by `SBJLocalization`. Presentation adapters for names and symbols are alongside the unit models.
