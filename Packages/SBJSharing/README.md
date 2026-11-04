# SBJSharing

`SBJSharing` provides SwiftUI/UIKit presentation for sharing content, exporting documents, previewing files, and composing messages. It is a presentation layer: prepare your file or data in the owning feature, then hand that content to a sharing or export control.

## Getting started

Present the system export picker for a file URL your application has prepared:

```swift
import SwiftUI
import SBJSharing

struct ExportScreen: View {
    let exportURL: URL

    var body: some View {
        DocumentExportView(urls: [exportURL], asCopy: true)
    }
}
```

For a low-level system activity sheet, `ShareSheet(activityItems:)` bridges `UIActivityViewController`. For reusable feature UI, use `SBJSharePresentationHost` with `SBJShareButton` and `SBJSharePayload`; the host manages the presentation lifecycle. `DocumentPreviewSheet` offers Quick Look-style preview with sharing controls on supported platforms.

The UIKit-backed views are platform-conditional. Check the application's target and the source availability guards when using them in a multi-platform product. The application remains responsible for preparing accessible URLs and handling any required file permissions.

## macOS

Native macOS uses `NSSharingServicePicker` for share actions, `NSOpenPanel` for choosing a destination folder, `NSSavePanel` for exporting one document, and QuickLookUI for previews. The stable `SBJSharePresenter` and `SBJShareButton` flow is shared with iOS. `SBJShareActivity` aliases `UIActivity` (UIKit) or `NSSharingService` (AppKit); `SBJSharePayload` accepts `SBJImage` on either platform.

For multi-file export, macOS requests a destination folder. Files retain their names, and collisions report errors rather than silently replacing existing files. The exporting view currently logs file-operation failures; applications requiring explicit recovery should coordinate export errors in their own document layer.
