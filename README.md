# SBJFoundation

SBJFoundation provides shared SwiftUI editing, platform utilities, image and resource presentation, units, and application infrastructure. The structural data model is in its embedded **SBJDataDefinition** package; localization types remain in **SBJLocalization**.

```swift
import SBJFoundation
import SBJDataDefinition

@SBJEditable
struct Recipe: Codable {
    @SBJString(maxLength: 80)
    var name: String

    @SBJInteger(range: 1...24)
    var servings: Int
}
```

For a data-only model, use `@SBJStructure` and `import SBJDataDefinition` instead of `@SBJEditable`.

## Package ownership

- **SBJFoundation**: `@SBJEditable`, SwiftUI editing and editor macros, platform adapters, media and user-interface utilities.
- **SBJDataDefinition** (`Packages/SBJDataDefinition`): `@SBJStructure`, structural protocols, metadata, validation, search, and data macros. Its compiler-side macro support is shared with the Foundation editor plugin.
- **SBJLocalization**: `SBJPropertyInfo` and localized presentation services.
- **SBJDocuments**, **SBJFileResources**, **SBJCamera**: separately packaged storage, resource, and camera functionality.
- **SBJStructuredEditor**: an existing package dependency retained by this project.

Swift Package Manager target/product boundaries are defined in `Package.swift` and the nested package manifests; directories alone do not create modules.

## Documentation

- [Editor guide](Documentation/Editor/EDITOR_GUIDE.md)
- [Editor-specific annotations](Documentation/Editor/EDITOR_ANNOTATIONS.md)
- [Editor organization](Documentation/Editor/ORGANIZATION.md)
- [Editor sample coverage](Documentation/Editor/SAMPLE_COVERAGE.md)
- [Accessibility regression checklist](Documentation/Editor/ACCESSIBILITY_REGRESSION.md)
- [Help](Packages/SBJHelp/Documentation/Help-System.md), [Units](Documentation/UNITS.md), [Image document](Documentation/Image/IMAGE_DOCUMENT.md), [Tags](Documentation/Tags.md), [Testing](Documentation/TESTING.md)
- [Phase 7 audit](Documentation/PHASE7_AUDIT.md)
- [SBJDataDefinition](Packages/SBJDataDefinition/README.md)
- [SBJLocalization](Packages/SBJLocalization/README.md)
- [SBJDocuments](Packages/SBJDocuments/README.md)
- [SBJFileResources](Packages/SBJFileResources/README.md)
- [SBJCamera](Packages/SBJCamera/README.md)


## Help extraction

The reusable Help UI is in [Packages/SBJHelp](Packages/SBJHelp/README.md). Foundation-owned HTML pages remain in `Sources/SBJFoundation/Resources/Help/`; `SBJHelpConfiguration.foundation` supplies their token references. Platform URL opening is owned by SBJFileResources.
