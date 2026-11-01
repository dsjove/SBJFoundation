# SBJUIVocabulary

`SBJUIVocabulary` provides reusable SwiftUI controls and presentation conventions: symbol buttons, selection surfaces, form fields, numeric and text inputs, font/color UI, attachment previews, and consistent visual states. It keeps common controls out of feature-specific screens.

## Getting started

```swift
import SwiftUI
import SBJUIVocabulary

struct ReferenceLink: View {
    let documentationURL: URL

    var body: some View {
        SBJURLButton(
            url: documentationURL,
            title: "Documentation",
            style: .titleAndIcon
        )
    }
}
```

For common actions, choose controls such as `SBJAddButton`, `SBJDeleteButton`, `SBJDismissButton`, and `SBJSymbolButton` before constructing a one-off equivalent. `SBJSelectionMenu` and `SBJSelectionView` handle selection UI; `NumberTextField`, `SearchField`, and `UnitValueControl` cover specialized inputs.

The underlying `CodableColor`, `CodableFont`, and unit models belong to `SBJDataDefinition`; this package provides their UI representation. Some controls are platform-conditional, so import and use the surfaces available to your target.
