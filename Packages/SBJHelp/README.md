# SBJHelp

`SBJHelp` shows bundled help content in SwiftUI applications. It resolves resources, applies template substitutions and selects an appropriate presenter, including support for HTML and Markdown. Help source files belong to the feature that documents them.

## Getting started

Create an `SBJBundledContentReference` for a resource in your own application or package, then present it using `SBJHelpLink`:

```swift
import SwiftUI
import SBJHelp
import SBJFileResources

struct FeatureHelp: View {
    let helpAsset: SBJBundledContentReference

    var body: some View {
        SBJHelpLink(asset: helpAsset)
    }
}
```

The same asset can be presented via `SBJHelpButton` in toolbar layouts. Use `SBJHelpConfiguration` for shared presentation settings and `SBJHelpTemplateRenderer` when resource content needs substitutions before display.

