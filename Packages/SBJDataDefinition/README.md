# SBJDataDefinition

SBJDataDefinition owns the **structural data layer** used by SBJFoundation and other consumers: `@SBJStructure`, structural protocols and metadata, validation and comparison, structural search, default construction, referenced-content traversal, Swift source encoding, and data-property annotations.

`SBJPropertyInfo` itself belongs to **SBJLocalization**, which this package depends on. SwiftUI editor implementations and the `@SBJEditable` umbrella annotation remain in **SBJFoundation**.

## Use

```swift
import SBJDataDefinition

@SBJStructure
struct Recipe: Codable {
    @SBJString(maxLength: 80)
    var name: String
}
```

For editor integration, import SBJFoundation and use `@SBJEditable` instead; do not apply both annotations.

## Targets and shared macro generation

`Package.swift` declares three production targets:

- `SBJDataDefinition`: runtime library and public data macro declarations. It depends on `SBJLocalization` and on its macro plugin.
- `SBJDataDefinitionMacros`: compiler plugin that registers data macro entry points. It depends on the shared support target.
- `SBJStructureMacroSupport`: ordinary **compiler-side** SwiftSyntax library containing reusable structural syntax analysis and code generation. It is also exposed as a package product so **SBJStructuredEditorMacros** in the parent package can import it.

SwiftPM compiles the shared support target for the **host toolchain** as a dependency of the macro plugins. The compiler loads the plugins when expanding annotations, and the plugins generate Swift declarations into the client's compilation. The client's application does **not** call or link `SBJStructureMacroSupport` as a runtime API. A runtime dependency on `SBJDataDefinition` alone does not expose macro implementation types; the editor macro target explicitly depends on the support product.

## Documentation

- [Structural model guide](Documentation/STRUCTURAL_MODEL_GUIDE.md)
- [Data annotations and values](Documentation/ANNOTATIONS_AND_VALUES.md)
- [Package and source organization](Documentation/ORGANIZATION.md)
- [Swift source encoding](Documentation/SWIFT_SOURCE_ENCODING.md)

Macro expansion tests and runtime tests live under `Tests/SBJDataDefinitionTests`.

## Presentation declarations

`SBJDataDefinition` defines the `@SBJStringPresentation`, `@SBJArrayPresentation`,
`@SBJSetPresentation`, `@SBJFieldPresentation` annotation and `SBJPresentationDisclosureMode`.
These are declarative presentation preferences, not SwiftUI implementations.
`@SBJStructure` reads applicable annotations and generates the corresponding
structural metadata and hints. Presentation consumers choose how to render them.

The generated structural model and its traversal never require an editor instance.

## Codable models and sample coverage

The `Sources/SBJDataDefinition/Codables` directory owns Units, Fonts, and Colors model types. The accompanying model-specific structural adapters supply generated-metadata-equivalent traversal, validation, and source encoding behavior. The DEBUG-only comprehensive sample fixture is in `Sources/SBJDataDefinition/Codables/Sample`. Presentation annotations live in `Annotations`.


## Type-level `SBJPropertyInfo` defaults

Reusable domain value types can adopt `SBJDefinitionTypeInfoProviding` and supply a
static `definitionTypeInfo: SBJPropertyInfo`. When `@SBJStructure` metadata or
`@SBJPropertyInfo`-generated lookups resolve a property, each absent attribute
(title, summary, details, symbol, accessibility label and accessibility hint)
falls back independently to the property's declared value type. Explicit property
values always win. Optional properties inherit defaults from their wrapped type.
Primitive types without a provider are unchanged. No model instance is needed.

```swift
struct Status: Codable, SBJDefinitionTypeInfoProviding {
    static let definitionTypeInfo = SBJPropertyInfo(
        title: "Status", summary: "Current lifecycle status")
    var rawValue: String
}
```

This is *type* documentation, not a replacement for property-specific meaning.
Handwritten metadata accessors must explicitly call `SBJDefinitionTypeInfo.resolve(_:for:)`;
macros cannot rewrite custom implementations. Tests in
`Core/SBJDefinitionTypeInfoTests.swift` exercise precedence and optional types.

The printable catalog/PDF lives in the separate `SBJDataDefinitionReport` package.
