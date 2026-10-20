# SBJUnits (scaffold)

No unit implementation has moved from SBJFoundation.

## Codable gap
Foundation Measurement/Dimension provide conversions, but the application's stored models need a stable, strongly typed Codable nomenclature for supported units and a Codable UnitValue that retains the chosen unit. The planned package fills that gap while still using Foundation for conversions.

## Planned organization
Use the character model package's Nomenclature shape for unit identifiers and common units; keep model/validation separate from reusable UI. The editor adapter stays in SBJStructure. Model annotations use `@SBJStructure`, not `@SBJEditable`.

## Dependencies
SBJDataDefinition, SBJLocalization, SBJUIVocabulary and SBJHelp; no dependency on editor.
