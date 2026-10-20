# SBJUIVocabulary

Reusable SwiftUI presentation vocabulary shared by application screens, unit controls and the structured editor.

## Use

```swift
import SBJUIVocabulary

SBJURLButton(url: documentationURL, title: "Documentation", style: .titleAndIcon)
```

`SBJURLButton` supports `.iconOnly`, `.titleOnly` and `.titleAndIcon`; URL validation/opening deliberately uses `SBJFileResources`, **not** SwiftUI's `openURL` environment. `SBJSelectionMenu` centralizes choice presentation and uses a picker on watchOS for binding-based selection. Its action-menu variant remains an action menu.

The package also contains `SBJUIAppearance`, symbol buttons, fonts, controls, field sizing and text-input policies. Sizing values are heuristics rather than measured glyph bounds; see the sizing source TODOs for planned work. Some controls are currently used primarily by the editor, but remain part of this shared vocabulary.

## Dependencies

`SBJDataDefinition`, `SBJLocalization` and `SBJFileResources`.

## Tests

Test selection decisions, disabled behavior, sizing policy and other independently observable results. Simple construction and accessors do not need runtime tests.
