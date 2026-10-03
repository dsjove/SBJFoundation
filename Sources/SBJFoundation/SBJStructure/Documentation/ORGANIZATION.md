# SBJStructure Source Organization

SBJStructure is organized for two kinds of discovery:

1. **Public API discovery** — `Public/` directories are the deliberate "start here" surface.
2. **Implementation discovery** — non-public files are grouped by the behavior they implement, not by Swift declaration kind.

The directory structure is therefore intentionally not a taxonomy such as `Enums/`, `Protocols/`, or `Views/`.

## Top level

```text
SBJStructure/
├── Public/
│   ├── Annotations/   # @SBJStructure and property annotations
│   ├── Model/         # structural/editable model contracts and metadata
│   ├── Content/       # content inspection
│   ├── Comparison/    # structural comparison
│   ├── Validation/    # invariants, validation paths, diagnostics
│   └── Resources/     # structural resource discovery
├── Editor/
│   ├── Public/        # SBJEditorView, SBJEditField, registry, search/navigation API
│   ├── Automatic/     # generated-property composition and dispatch
│   ├── Controls/      # concrete editing behavior by user task
│   │   ├── Text/
│   │   ├── Numbers/
│   │   ├── Values/
│   │   └── Collections/
│   ├── Interaction/   # search, change state, focus/actions, text-input policy
│   ├── Layout/        # adaptive layout and accessibility presentation semantics
│   └── Support/       # type-erasure and binding support
├── SwiftEncoder/
│   ├── Public/        # source-export API and protocols
│   └── Support/       # encoder implementation helpers
├── Preview/           # canonical sample model and SwiftUI previews
└── Documentation/
```

## Public directories

A `Public/` directory means "look here first when learning the feature." It is a discoverability convention, not an assertion that every technically `public` symbol is intended as primary API. Some macro-generated implementation contracts must remain visible across module boundaries and therefore live with the implementation they support rather than being promoted into the public entry surface.

For example, `SBJEditorPropertyDescriptor` is public because `@SBJStructure` expansion in a client module must be able to name it, but it remains under `Editor/Automatic/` because application code should normally start with `SBJEditorView` or `SBJEditField` instead.

## Canonical sample model

`Preview/SBJStructureSampleModel.swift` is the single canonical SBJStructure sample fixture.

It is intentionally **internal but not DEBUG-only** so it can serve three purposes:

- the automatic structured-editor preview;
- the standalone `SBJEditField` preview;
- `@testable` integration tests.

Both editor previews must use this model rather than maintaining independent fixture families. Extra properties needed only to exercise standalone editor dispatch are marked `@SBJNotEditable` so they remain available for direct bindings without cluttering the automatic editor.

Focused unit tests should still define tiny local fixtures when a test needs a very specific shape. The canonical sample model is for cross-feature integration coverage, not a replacement for precise unit fixtures.
