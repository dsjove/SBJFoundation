# SBJFoundation

`SBJFoundation` is the low-level shared framework for SBJ applications. It extends Apple platform frameworks with reusable primitives that are broadly useful across SBJ products: Codable/platform bridges, presentation vocabulary, image/resource content, search, units, and the SBJStructure structured-model/editor subsystem.

The framework is deliberately not a home for application workflow or domain policy. **SBJStructure remains SBJStructure** inside this package; the package name describes its layer, not a replacement identity for its major subsystems.

```swift
import SBJFoundation

@SBJStructure
struct Recipe: Codable {
    @SBJString(maxLength: 80)
    var name: String

    @SBJInteger(range: 1...24)
    var servings: Int
}
```

## Framework boundaries

```text
Apple platform frameworks
        ↓
   SBJFoundation
      ↓       ↘
 shared       SBJLayout
 packages        ↓
      \        /
       Applications
```

- **SBJFoundation** owns reusable values and contracts close to Apple frameworks: platform extensions, Codable support, presentation/UI vocabulary, image/resource payloads, search, units, observation helpers, shared application workflows, and SBJStructure + SubjectEditor.
- **SBJLayout** owns newspaper/print-style pagination, geometry, fitting, and PDF rendering. It may depend on SBJFoundation.
- **Other shared packages** may depend on SBJFoundation for lower-level contracts, but SBJFoundation must not depend on them.
- **Applications/domain packages** own domain vocabulary, business rules, document policy, resource-store policy, vendor/server policy, and final presentation choices.

See [Framework Ownership and Dependency Boundaries](Documentation/ARCHITECTURE.md) for the canonical ownership statement.

## Source organization

Directory placement communicates ownership; it does not create separate modules.

- `Sources/SBJFoundation/SBJStructure/` — functionality-first subsystem with explicit `Public/` entry surfaces, automatic/editor implementation areas, source export, documentation, and one canonical sample fixture.
- `Sources/SBJFoundation/Image/` — reusable image references and image-resource UI, including `ImageReference`, `PhotoMenu`, and thumbnail/display controls.
- `Sources/SBJFoundation/UIVocabulary/` — shared SwiftUI visual vocabulary: semantic appearance, field chrome, active/focus/validation/search decoration, alerts, buttons, and reusable controls.
- `Sources/SBJFoundation/Search/` — general search values, matching, and `SearchField`.
- `Sources/SBJFoundation/Codables/` — Codable representations for platform-facing values.
- `Sources/SBJFoundation/PlatformExtensions/Foundation/` — Foundation-centered types and extensions, including `SBJResourceContent`
- `Sources/SBJFoundation/PlatformExtensions/UIKit/` — UIKit realization/bridges for platform-neutral values.
- `Sources/SBJFoundation/Units/` — codable reusable measurement semantics and editing policy.
- `Sources/SBJFoundation/Localization/` — presentation/localization building blocks shared across renderers.
- `Sources/SBJFoundation/Help/` — application help resources, UTType-based presenter dispatch, HTML/Markdown rendering, template substitution, About, and help presentation.
- `Sources/SBJFoundationMacros/` — macro implementations used by SBJStructure annotations.

See [Legacy Photo Workflow](Documentation/LEGACY_PHOTO.md) for the status and rewrite boundary of the quarantined photo APIs.

`ImageReference` is the single concrete image reference type. It covers asset-catalog images, ordinary bundled image files, system symbols, and file-backed image sources with `none`, `asset`, `resource`, `system`, and `file` cases realized by SwiftUI/UIKit adapters. `SBJAssetReference` is deliberately separate: it is the generic data-loading reference for asset-catalog data sets and arbitrary bundle resources such as HTML/CSS. Both use the same bundle-resource lookup helper so processed-resource flattening is handled consistently.

## Help

SBJFoundation owns the application help system directly. HTML bundle resources and legacy data assets remain first-class; Markdown is also supported. Help representations are selected through `UTType`, and additional presenters can be introduced without changing the shared sheet/chrome. `SBJHelpLink` uses native SwiftUI HelpLink where the SDK exposes it and the shared UIVocabulary fallback on iOS/Mac Catalyst. About is intentionally a help resource and remains available from the help toolbar.

See [Help System](Documentation/HELP.md).

## SBJStructure and SubjectEditor

SBJStructure describes the structure of Codable models independently from business semantics. Generated metadata supports validation, comparison, content inspection, diagnostics, resource-reference discovery, source export, accessibility, and SubjectEditor.

`SBJStructureSampleModel` is the kitchen-sink compile/sample fixture shared by `SBJStructuredEditorPreview`, `SBJEditFieldPreview`, and integration tests. Every SBJStructure annotation must be represented in that model. For hand-built SwiftUI forms, `SBJEditField` exposes the same one-value editor selection used by the automatic editor, so an application can bind a `String`, `Date`, `Data`, collection, nested structured value, or other supported type without hosting an auto-generated form. For `SBJSwiftUIEditable` models, `SBJEditField(root:keyPath:)` also reuses generated property metadata and key-path registry customizations; the automatic editor renders its properties through that same field component. `SBJEditFieldPreview` demonstrates each supported editor category independently. See:

- [SBJStructure design and rationale](Sources/SBJFoundation/SBJStructure/Documentation/README.md)
- [SBJStructure source organization](Sources/SBJFoundation/SBJStructure/Documentation/ORGANIZATION.md)
- [SBJStructure sample coverage](Sources/SBJFoundation/SBJStructure/Documentation/SAMPLE_COVERAGE.md)
- [Accessibility regression checklist](Sources/SBJFoundation/SBJStructure/Documentation/ACCESSIBILITY_REGRESSION.md)

## Resource identity, content, and images

SBJFoundation separates semantic resource identity from encoded payload:

- `SBJResourceID` is the stable reference stored by structured/document models.
- `SBJResourceContent` is an unnamed encoded payload: `Data` plus its Foundation `UTType`.
- `SBJResourceDiscovery` finds `SBJResourceID` usages throughout generated SBJStructure graphs and standard containers.

That boundary keeps file locations, UIKit objects, persistence callbacks, and application-specific attachment semantics out of structured models.

`PhotoMenu` edits a `Binding<SBJResourceContent?>`. Files, Photos, and Paste preserve encoded image bytes and content type when available; Camera output is encoded off the main actor. `PhotoThumbnailView` and `PhotoDisplayView` provide reusable presentation around the same resource-content model. The application remains responsible for storing returned content, assigning or retaining `SBJResourceID`, garbage collection, and document-save policy.

## Search and editor filtering

`SearchField` is reusable outside SubjectEditor and can optionally show the standard active-search decoration itself. `SBJEditorSearchBar` suppresses that field-local decoration and applies the same decoration around the complete search/filter control group whenever text, Changed-only, or Empty-only filtering is active.

Structural search/filter criteria are represented independently of SwiftUI by `SBJEditSearchCriteria`; editor views consume those criteria through the SubjectEditor environment.

## Localization and presentation resources

Localization is treated as a broader presentation-resource problem spanning text, formatting/units, imagery/symbology, semantic color, accessibility, vendor/document/server policy, and renderer fitting. The shared design is documented in [Localization and Presentation Resources](Documentation/LOCALIZATION_AND_PRESENTATION_RESOURCES.md).

SBJFoundation owns shared semantic/resource contracts. SBJLayout owns geometric selection and print/PDF rendering. Applications own domain meaning and policy.

## Testing

SBJFoundation is low-level enough that refactoring should be protected by focused behavior tests. SubjectEditor preview compile coverage complements, but does not replace, tests for structural behavior, macros, resource discovery/sendability, accessibility/localization, Codable support, observation, units, and editor behavior.

See [Testing](Documentation/TESTING.md).


## Camera

Camera capture APIs and required host-app project configuration are documented in [Documentation/CAMERA.md](Documentation/CAMERA.md).
