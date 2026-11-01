# SBJLocalization

`SBJLocalization` supplies user-facing presentation metadata and vocabulary: readable labels and descriptions, semantic symbols, accessibility metadata, and text presentation conventions. Other packages use these definitions without depending on a particular screen or editor.

## Getting started

Use `SBJPropertyInfo` to describe the meaning of a property and provide accessible defaults:

```swift
import SBJLocalization

let info = SBJPropertyInfo(
    title: "Attunement",
    summary: "Current attunement state"
)
let accessibility = info.accessibility
// label: "Attunement"; hint: "Current attunement state"
```

`accessibilityLabel` and `accessibilityHint` override those defaults when supplied. Longer `details` text is not automatically spoken as the accessibility hint. Adopt `SBJTextPresentable` for model-specific readable text; use `SBJSymbology` and `SBJSymbol` for semantic icons rather than hard-wiring glyph names throughout UI code.

## Future design capabilities

The design documents in `Documentation/` discuss proposed directions, **not guaranteed APIs or implemented behavior**:

- Context-aware localized wording for the same concept in different presentation locations.
- Layered resolution of application, feature, and library wording and overrides.
- Localization of property names, summaries, and longer descriptions while preserving semantic metadata.
- Consistent localization of symbols, accessibility descriptions, and user-facing controls where appropriate.
- Migration paths for existing literal and presentation strings without changing current behavior prematurely.
- Integration with SBJLayout and other rendering layers so localized presentation is usable outside SwiftUI.

## Further reading

- [Layered and context-aware localization](Documentation/LAYERED_CONTEXT_AWARE_LOCALIZATION.md)
- [Layout localization](Documentation/SBJLAYOUT_LOCALIZATION.md)
- [Character localization](Documentation/CHARACTERS_LOCALIZATION.md)
