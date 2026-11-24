# SBJFoundation

SBJFoundation is a collection of Swift packages for typed document models, structured editing, nomenclature, accessibility, help, reporting, and application integrations. The `Packages/` directory contains the individual products; consumer applications live in separate repositories.

## Structured-model architecture

The structured-data features follow a shared contract:

1. **SBJDataDefinition** owns `@SBJStructure`/extension annotations, declared-property identity, `SBJNomenclature`, constraints, traversal, type/initializer metadata, defaults, construction, and invariant checking. The Swift encoder produces source representations; it is not a runtime Swift interpreter.
2. **SBJStructuredEditor** is the SwiftUI consumer. It uses typed property descriptors, the shared collection creation infrastructure, and usage policies rather than imposing new model invariants.
3. **SBJStructuredAI** uses the same structural descriptors to search/read/describe fields, list matching fields, prepare proposed scalar/collection edits, and handle explicit approval. Apple Foundation Models is a tool-calling adapter around this deterministic layer.
4. **SBJDataDefinitionReport** produces a declaration-level PDF catalog without constructing a model instance. Editor visibility does not imply report exclusion; annotated computed members are documented without invoking getters.
5. **SBJLocalization**, **SBJUIVocabulary**, and **SBJHelp** provide shared human-facing nomenclature, UI presentation and help.

Nomenclature supplies titles, alternative names, summaries, descriptions, symbols and accessibility metadata. For declarations using `#SBJAutoNomenclature`, the title is derived by macro expansion rather than recomputed by every consumer. A standalone nomenclature may have an empty title; clients that need optional-title semantics can use `nonEmptyTitle`.

## Capability, policy and invariant

These are distinct layers. Swift and typed structural descriptors determine which operations are *possible*. Explicit property constraints and whole-model invariants determine whether a candidate value is *valid*. `SBJUsagePolicy` interprets existing presentation hints for visual and semantic editors; a presentation hint must not expand an unsupported operation or override an invariant. In particular, `insertable`, `removable` and `reorderable` are editor policies rather than intercepted ordinary Swift mutations. The report can describe fields that an editor excludes.

Unit constraints on `@SBJUnitValue` can specify a required unit and an allowed unit system; the `UnitValue<U>` generic parameter establishes its unit family. `defaultUnit` is a construction preference, not automatically a required unit. The former `SBJUnitValuePresentation` duplicate has been removed.

## Construction and approval

`SBJCollectionElementCreatable` and `SBJDefaultValue` are shared by the editors. `SBJRuntimeConstruction` canonicalizes supplied member labels and aliases and constructs typed candidates using defaults with writable-member mutation when supported, otherwise Codable reconstruction. It does not dynamically execute arbitrary custom Swift initializers. Every candidate is subject to invariant validation. An AI proposal is not a mutation: the app must explicitly approve it, at which point revision/policy/invariant checks apply.

## Integration and verification

Read [the Assistant architecture and verification guide](Documentation/StructuredAssistantArchitecture.md) for tool routing, error handling, feedback/voice boundaries, tests and acceptance cases. Package-specific documentation remains in the respective `Packages/<name>/README.md` files. See [Nomenclature integration](Packages/SBJLocalization/Documentation/NomenclatureIntegration.md) for the shared naming/help contract.

The Linux validation of the Phase 8 snapshot performs syntax and source checks only; Xcode builds, platform-specific UI behavior, microphone permissions and live Foundation Models responses must be verified on Apple hardware.
