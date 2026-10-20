# SBJFoundation

SBJFoundation provides application-facing SwiftUI components, image and attachment presentation, tags, and platform integrations. Related capabilities are provided as separately importable local Swift packages. Choose the narrowest module that supplies the feature you need.

## Packages

| Module | Purpose |
| --- | --- |
| `SBJFoundation` | Application-level presentation and integration, including the current structured editor implementation |
| `SBJDataDefinition` | Codable structure annotations, structural metadata, validation, comparison and source encoding |
| `SBJLocalization` | `SBJPropertyInfo`, user-facing string presentation, accessibility and symbols |
| `SBJUIVocabulary` | Reusable SwiftUI buttons, menu controls, appearance, fonts and field sizing |
| `SBJUnits` | Typed, Codable quantities, unit nomenclature, conversion models and controls |
| `SBJFileResources` | File/URL utilities and security-scoped resources |
| `SBJDocuments` | Document persistence and storage operations |
| `SBJHelp` | Help views, bundled references and template rendering |
| `SBJCamera` | Camera capture UI and encoded captured-attachment data |
| `SBJStructuredEditor` | Package interface reserved for the structured editor; implementation is currently provided in `SBJFoundation` |

The nested packages have their own `Package.swift` files, READMEs, and test targets. Import each module explicitly when using its public API. Platform availability is controlled by the declarations and package manifest; not every UI feature is offered on every Apple platform.

## Working with structured models

Use `@SBJStructure` from `SBJDataDefinition` for models that need structural metadata without an editor dependency:

```swift
import SBJDataDefinition

@SBJStructure
struct Recipe: Codable {
    @SBJString(maxLength: 80) var name: String
    @SBJInteger(range: 1...24) var servings: Int
}
```

The editor annotation and editor presentation APIs currently live in the Foundation module. See the [editor guide](Documentation/Editor/EDITOR_GUIDE.md) and [editor annotations](Documentation/Editor/EDITOR_ANNOTATIONS.md).

## Guides

- [Testing philosophy and coverage](Documentation/TESTING.md)
- [Image document integration](Documentation/Image/IMAGE_DOCUMENT.md)
- [Tags](Documentation/Tags.md)
- [Structured editor](Documentation/Editor/EDITOR_GUIDE.md)
- [Unit concepts](Packages/SBJUnits/README.md)
- [Data structures](Packages/SBJDataDefinition/README.md)
- [Help](Packages/SBJHelp/README.md)
