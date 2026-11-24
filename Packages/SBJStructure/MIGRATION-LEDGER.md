# Cumulative package migration ledger

## Applied in SBJLocalization (already delivered)
- `SBJDefinitionTypeNomenclatureProviding` → `SBJNomenclatureProviding`
- `definitionTypeNomenclature` → `nomenclature`
- `SBJDefinitionTypeNomenclature.resolve` → `SBJNomenclatureResolver.resolve`
- `SBJNomenclature.mergingDefaults(from:)` belongs to `SBJLocalization`.
- `HasContentCheckable`, `SBJStructuralComparable`, `SBJStructuralCompare`, `SBJInvariantCheck` (general helpers), `SBJValidationError`, and `SBJValidationKeyPath` belong to `SBJLocalization/Invariant`.

## Applied in this iteration
- Swift package/library/module `SBJDataDefinition` → `SBJStructure`.
- Macro target/module `SBJDataDefinitionMacros` → `SBJStructureMacros` (all `#externalMacro(module:)` references updated).
- Test target/module `SBJDataDefinitionTests` → `SBJStructureTests`.
- All SBJStructure source and tests updated for the nomenclature rename. Structural nomenclature integration tests remain in this package; general semantic resolution tests belong to SBJLocalization. Duplicate domain-level semantic definitions removed.
- Structural specialization of `SBJContentCheck` and `SBJInvariantCheck` remains within SBJStructure.
- `Codable+SBJCopy.swift`, `Set+SBJReplace.swift`, and `SBJArrayMutation.swift` organized under `Codables/Foundation`; structural search adapter moved from `Codables/Foundation` to `Search`; sample integration models moved to `Samples`.

## Downstream, apply when those packages are reviewed (NOT changed now)
- Update manifest dependency `.package(path: "../SBJDataDefinition")` → `.package(path: "../SBJStructure")`.
- Update `.product(name: "SBJDataDefinition", package: "SBJDataDefinition")` → `.product(name: "SBJStructure", package: "SBJStructure")`.
- Update `import SBJDataDefinition` → `import SBJStructure`.
- Any macro support dependency `SBJDataDefinitionMacros` → `SBJStructureMacros`; `SBJStructureMacroSupport` remains unchanged.
- Replace old nomenclature provider/type/property names with their SBJLocalization equivalents.
- Evaluate consumer-side code in `SBJDataDefinitionReport`, `SBJStructuredAI`, and `SBJStructuredEditor` for possible general-purpose semantic contracts, but defer edits to their own review turns.

## Future candidate, NOT moved yet
- `SBJIssue<Kind>` is UI-independent diagnostics data with domain-level relevance, but moving it requires a separate SBJLocalization iteration. It stays in SBJStructure now to respect the one-package boundary.
- Existing `Codables` units and colors have standalone utility value; structure-specific adapters must remain here.

## Testing and correctness
- Tests are organized by the matching source area. Tests of general nomenclature fallback or validation path presentation have been removed from this package; they belong with the owning SBJLocalization APIs.
- Removed compile-only generic-conformance tests; retained behavioral Codable round-trip, structural metadata, comparison, and source-export tests.
- Guarded timestamp formatting against Int64 overflow after floating-point scaling and second rounding, and added a boundary regression test.
