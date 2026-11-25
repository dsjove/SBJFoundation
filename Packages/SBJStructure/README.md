# SBJStructure

`SBJStructure` provides opt-in structural metadata and operations for Swift models. Use it when your application needs typed inspection, traversal, validation integration, structural change detection, or Swift source export. The domain-level concepts themselves—nomenclature, meaningful content, structural equivalence, and general invariants—are provided by **SBJLocalization** and can be used without adopting `@SBJStructure`.

## Getting started

Add the `SBJStructure` library product and import it:

```swift
import SBJStructure

@SBJStructure
struct Note {
    var title: String = ""
    var count: Int = 0
    var summary: String { title }
}
```

The annotation generates one definition for accessible stored and computed properties. Codable and CodingKeys have no role in discovery. The generated machinery supports explicit inspection and validation; it does not intercept property access or automatically enforce invariants on mutation. See `Documentation/` for details of generated APIs and their usage.

### What this package owns

- **Annotations**: `@SBJStructure` and structural property configuration macros.
- **SBJStructure**: structural metadata, traversal, mutation, construction, structural content traversal, validation adapters, comparison integration, referenced-content inspection, and Swift source export.
- **Codables**: independently useful Codable models, Foundation value helpers, units, colors, fonts, and their presentation metadata. The structure-specific adapters for these types remain alongside them where necessary.
- **Search**: structure-aware search and classification.
- **Samples**: example models that exercise annotations and integration.

### The semantic boundary

Import `SBJLocalization` directly if all you need is to give a value a domain name (`SBJNomenclatureProviding`), decide whether it has meaningful content (`HasContentCheckable`), distinguish structural equivalence from application equality (`SBJStructuralComparable`), or validate a domain invariant (`SBJInvariantCheck`). These declarations are not redefined in `SBJStructure`; they are re-exported for existing structural clients.

Structural adapters, such as introspection through generated property metadata and rules attached through macros, remain in `SBJStructure`. `SBJDefaultValueCreatable` also remains here: default construction is a programming convenience, not a domain-meaning protocol.

### Macros and products

The public runtime product is `SBJStructure`. `SBJStructureMacroSupport` contains host-side SwiftSyntax generation helpers for macro clients; `SBJStructureMacros` is the Swift compiler macro plugin used by the annotations. These are implementation/tooling concerns, not runtime models for applications to adopt.

The package depends on the current `SBJLocalization` package and the SwiftSyntax toolchain version specified in `Package.swift`. For applications, the macro plugin is loaded during compilation, not at runtime.

### Important behavior

- Structured invariants run only when a client explicitly requests validation.
- The domain-level comparison API can differ from application-defined `Equatable`.
- `SBJContentCheck` supplies structure-aware content inspection on top of `HasContentCheckable`.
- `Codables` utility models do not require a client to adopt `SBJStructured`.
- Validation errors and paths come from `SBJLocalization`; structural validation adds configured property and collection context.

See `Documentation/Organization.md` and `MIGRATION-LEDGER.md` for organization and migration notes.

## Current refactoring contract

See [Iteration 2](Documentation/Refactoring-Iteration-2.md) for the new discovery, stored-state and consumer contracts, deliberate API removals, and verification limitations. It supersedes historical migration notes.

## Typed value operations

See [Documentation/ValueOperations.md](Documentation/ValueOperations.md) for executable scalar operations, safety rules, and a clearly labeled coverage roadmap for the other supported structural types. Collection and optional operations remain in the existing collection mutation engine.
