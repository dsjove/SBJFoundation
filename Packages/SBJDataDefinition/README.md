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

Macro expansion tests and runtime tests live under `Tests/SBJDataDefinitionTests`.

## Presentation declarations

`SBJDataDefinition` defines the `@SBJPresentationString`, `@SBJPresentationArray`,
`@SBJPresentationSet`, `@SBJPresentationDisclosure`, `@SBJPresentationExclude`,
`@SBJPresentationProperty` annotations and `SBJPresentationDisclosureMode`.
These are declarative presentation preferences, not SwiftUI implementations.
`@SBJStructure` reads applicable annotations and generates the corresponding
structural metadata and hints. Presentation consumers choose how to render them.

The generated structural model and its traversal never require an editor instance.

## Codable models and sample coverage

The `Sources/SBJDataDefinition/Codables` directory owns Units, Fonts, and Colors model types. The accompanying model-specific structural adapters supply generated-metadata-equivalent traversal, validation, and source encoding behavior. The comprehensive Recipe fixture is in `Sources/SBJDataDefinition/Samples/Recipe` and is restricted to DEBUG configurations. Presentation annotations live in `Annotations`.
