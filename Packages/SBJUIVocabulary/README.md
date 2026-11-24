# SBJUIVocabulary

`SBJUIVocabulary` is the shared **SwiftUI presentation vocabulary** for SBJFoundation applications and UI libraries. It offers small, reusable controls, input conventions, presentation states, and platform adapters. It does **not** own domain meaning, document persistence, reporting, help workflows, or application navigation.

## Using the package

```swift
import SwiftUI
import SBJUIVocabulary

struct ReferenceLink: View {
    let documentationURL: URL

    var body: some View {
        SBJURLButton(url: documentationURL, title: "Documentation", style: .titleAndIcon)
    }
}
```

Use `SBJAddButton`, `SBJDeleteButton`, `SBJRemoveButton`, `SBJDismissButton`, and `SBJSymbolButton` for common actions. **Delete** represents a destructive action (and can request confirmation); **Remove** represents removing an association or item without assuming deletion of its underlying resource. These actions are intentionally distinct.

`SBJSelectionMenu` and `SBJSelectionView` display selectable choices. `NumberTextField`, `SearchField`, `UnitValueControl`, and the reusable field modifiers cover common editing scenarios. Numeric/text sizing values are **layout preferences**, not guarantees of text fitting on every device or locale.

For shared visual meaning, use `SBJUIAppearance` and its appearance modifiers rather than repeating arbitrary colors and dimensions across clients. Share presentation, export, preview, and messaging controls live under `Sharing`, with `presentationChromeSuppression` used by the share host.

## Ownership boundaries

- **SBJLocalization** defines nomenclature, symbols, accessibility meaning, and other domain contracts.
- **SBJStructure** defines structural metadata and reusable Codable models such as `CodableColor`, `CodableFont`, and units. UI Vocabulary provides their SwiftUI adapters; it does not own their representations.
- **SBJFileResources** provides resource references and file-related operations.
- **SBJUIVocabulary** composes these into broadly reusable controls and UI state/presentation helpers.
- **SBJHelp** and application editors own their own feature workflows. Vocabulary additionally owns native share/export presentation through its dedicated `Sharing` area; it does not own document persistence.

The `Attachments` directory supplies a reusable attachment editor and a public Quick Look surface. The `Sharing/Documents` preview reuses that Quick Look bridge rather than duplicating native adapters. Sharing and preview controls are UI presentation surfaces, not document persistence or CloudKit management.

## Source organization

| Directory | Responsibility |
|---|---|
| `Appearance` | Shared semantic visual states, focus and selection modifiers |
| `Buttons` | General action controls |
| `Fields` | Text/numeric/unit inputs and field sizing |
| `Menus` | Choice and selection presentation |
| `Color`, `Font` | SwiftUI presentation of foundational value models |
| `ViewModifiers` | General-purpose view composition |
| `Attachments` | Existing attachment presentation and editing feature |
| `Sharing/Activities` | Native share activity types and payloads |
| `Sharing/Presentation` | Share sheets, buttons, hosts, presenter and chrome lifecycle |
| `Sharing/Documents` | Document picker, export, and preview presentation |
| `Sharing/Messaging` | Native message composition |
| `Resources` | Bundled UI/help resources |

## Availability, testing, and limitations

The manifest supports iOS 17, macOS 14, Mac Catalyst 17, watchOS 10, visionOS 1, and tvOS 17. Individual views are conditionally compiled and may not exist on every platform. Native color, font, and attachment preview behavior differs by OS. Check availability before consuming a platform-specific control.

Tests emphasize deterministic policies (menu selection, sizing) and value conversions. UI rendering, accessibility layout, Quick Look, and focus behavior also require visual or integration testing in a consuming application; compile-only view instantiation is not considered behavioral coverage.

## Sharing and document presentation

Sharing functionality previously distributed as `SBJSharing` is now part of this library. Import `SBJUIVocabulary` for `SBJShareButton`, `SBJSharePresentationHost`, `SBJSharePayload`, `ShareSheet`, `DocumentExportView`, `DocumentDestinationPicker`, `DocumentPreviewSheet`, and `MessageComposeView` (where supported). Existing type and initializer names are retained.

```swift
import SwiftUI
import SBJUIVocabulary

struct ExportScreen: View {
    let exportURL: URL
    var body: some View {
        DocumentExportView(urls: [exportURL], asCopy: true)
    }
}
```

Prefer `SBJSharePresentationHost` with `SBJShareButton` for coordinated sharing. `DocumentPreviewSheet` provides a Quick Look document preview with Open and Share actions, using the same native Quick Look bridge as `AttachmentPreviewSheet`. Client applications must prepare accessible files and manage their permissions. On macOS, native panels and services are used; on iOS and Catalyst, UIKit presentation is used. These controls are conditional by platform, and are not generally offered on watchOS or tvOS.

`PresentationChromeSuppressionAction` and `EnvironmentValues.presentationChromeSuppression` are also supplied by `SBJUIVocabulary`, so hosts can temporarily suppress their chrome during a share sheet. The default action is a no-op.

See [API ownership and future considerations](Documentation/Ownership.md) for distinctions worth preserving when extending the package.
