# Phase 7 — dependency, API, and source audit

Baseline: Phase 5 SBJFoundation project, including embedded Packages/SBJDataDefinition. Previous Xcode build/test success applies to Phase 4; Phase 5 and this Phase 7 edit have **not** been Xcode-built in this environment.

## One applied dependency correction

Removed the `SBJStructureMacroSupport` product from the **SBJFoundation runtime target** dependencies. That target does not import compiler-side macro support. The product remains a dependency of `SBJFoundationMacros` and `SBJFoundationTests`, where expansion/fixture code uses it. No macro code, editor code, or runtime API was moved.

## Verified by static audit

- SBJDataDefinition is still embedded at `Packages/SBJDataDefinition`.
- Foundation's package manifest retains the `SBJDataDefinition` and `SBJStructuredEditor` package references.
- `@SBJStructure` is declared in SBJDataDefinition; `@SBJEditable` remains in Foundation.
- Structural macro implementation is in the SBJDataDefinition compiler plugin; editor macro implementation remains in Foundation.
- Shared structural generator is single-sourced in SBJStructureMacroSupport.
- No occurrences of `SBJEditableField`, `sbjEditableFields`, `SBJFoundationType`, or `sbjStructureTypeName` in current Swift source.
- No SBJDataDefinition source file imports its own module.
- No missing direct SBJDataDefinition import was found among SBJFoundation runtime files that directly reference key extracted structural names or macros (heuristic search, not a compiler check).
- Existing SBJLocalization implementation left untouched, including its optional property-information fields.

## Boundaries intentionally left unchanged

- The placeholder SBJStructuredEditor package remains; editor implementation still lives in SBJFoundation.
- Foundation has an existing `@_exported import SBJLocalization` for localization metadata. This is not a new compatibility alias. Removing it could alter the established API and should be decided separately.
- The shared compiler-side support target still contains `SBJEditorGeneration` to allow editor generation reuse. This does **not** move editor runtime code but is worth revisiting when the editor macros become their own package.
- Existing TODO comments outside the extracted structural layer were not modified.

## Required Xcode verification

1. Build and run SBJDataDefinition tests.
2. Build and run SBJFoundation tests.
3. Rebuild Jove's Characters and SBJLayout applications from their successfully integrated working copies.

Only the first two are prerequisites for accepting this small Phase 7 Foundation manifest change. The app builds were reported successful earlier against the Phase 5 API, but have not been rerun with this exact archive.
