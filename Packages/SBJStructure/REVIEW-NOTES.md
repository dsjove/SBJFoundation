# SBJStructure quality review notes

## Scope and verification

This iteration changes only the former `SBJDataDefinition` package. All other packages are unchanged, including `SBJLocalization`. Swift 6.4 and Apple's SDKs are required for the real build, SwiftSyntax macro expansion, and test run. The Swift 6.2.1 toolchain available here was used for per-file syntax parsing and a temporary tools-version override to inspect the manifest; it is not a successful build.

## Domain-semantic boundary

`SBJLocalization` already owns `SBJNomenclatureProviding`, `SBJNomenclatureResolver`, `HasContentCheckable`, `SBJStructuralComparable`, `SBJStructuralCompare`, `SBJValidationKeyPath`, `SBJValidationError`, and generic invariant entry points. Remove the former duplicate definitions from SBJStructure. Retain SBJStructure-dependent inspection, traversal, generated metadata, collection titles, and specialized invariant rules as adapters in this package. Keep `SBJDefaultValueCreatable` here as a programming concept.

## Package rename

The Swift package, runtime module, macro plugin and test targets are renamed to `SBJStructure`, `SBJStructureMacros`, and `SBJStructureTests`; `SBJStructureMacroSupport` retains its name. All macro `#externalMacro(module:)` references and generated code strings in this package have been updated. See `MIGRATION-LEDGER.md` for required downstream changes when those packages are reviewed.

## Codable and foundational utilities

`Codables` includes reusable value models and Foundation/collection conveniences that do not require SBJStructure. `Codable+SBJCopy`, `Set+SBJReplace`, and `SBJArrayMutation` live under `Codables/Foundation`. The structure-specific search adapter moved out of Codables to `Search`. Example integration models moved to `Samples`. The structural adapters for Codable values remain with their associated types, rather than promoting SBJStructure dependencies into a simpler package.

## Correctness fix

`TimeInterval.timestampString` now checks scaled and rounded millisecond values before converting to Int64. This avoids a potential runtime trap near the Int64 boundary, including the whole-second rounding step. A regression test covers the boundary. No other behavioral changes are intended.

## Test review

Existing meaningful macro-expansion, structural inspection, traversal, validation integration, comparison, source export, and Codable round-trip tests are retained and reorganized by their source area. A compile-only generic-conformance test and package-local tests covering only semantics now owned by SBJLocalization were removed. Testing of authored human-readable wording is not a goal; tests that compare generated Swift syntax or machine-readable representation remain.

## Documentation

README and organizational guide now address clients of the renamed library. Document links were repaired, obsolete `SBJUnits` package instructions were replaced with current guidance for `Codables/Units`, and annotation configuration documents distinguish implemented contracts from future work.

## Reuse evaluation of downstream consumers — no edits made

- `SBJDataDefinitionReport` (existing external package name): report schemas and transformation models are connected to `SBJStructured` discovery or report presentation. They should remain report-owned unless standalone semantic usage emerges. They need the `SBJStructure` dependency/import migration in their turn.
- `SBJStructuredAI`: `SBJSemanticOccurrenceCatalog` and related field-resolution types describe structure-addressable paths and AI read/write interactions. Their current use depends on structural property discovery; do not lift those into SBJLocalization merely because they contain 'semantic' in their name. Evaluate any independently useful field-reference type in that package's own iteration.
- `SBJStructuredEditor`: traversal, bindings, and editor row identities remain presentation/integration concerns. Domain concepts such as nomenclature and meaningful content should be sourced from SBJLocalization, while UI behavior should stay in the editor package.
- `SBJIssue<Kind>` and its generic diagnostic collection are independent of editor UI and may deserve domain-level ownership later. They are deliberately retained here: moving them into SBJLocalization now would violate the one-package-per-iteration boundary.

## Client build guidance

Place the delivered `SBJStructure` directory beside your updated `SBJLocalization` directory, so `../SBJLocalization` resolves to the already-delivered semantic package. Build and test `SBJStructure` by itself. Do not attempt to build the full SBJFoundation workspace until downstream packages have been migrated.
