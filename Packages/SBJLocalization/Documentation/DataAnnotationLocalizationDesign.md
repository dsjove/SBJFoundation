### Accessibility and localization regression harness

The canonical sample model is also the framework's accessibility/localization regression surface. The automatic and standalone editor previews plus integration tests all exercise that one fixture rather than maintaining separate preview-only or test-only models.

The preview matrix covers default and dark appearance, large Dynamic Type, a narrow AX5 layout, French and German locales, Arabic right-to-left presentation, and a deliberately changed/empty/invalid model state. System settings that are read-only SwiftUI environment values on the supported target (including Increase Contrast, Differentiate Without Color, and Reduce Transparency) are verified through Xcode Environment Overrides / Accessibility Inspector.

`SBJAccessibilityLocalizationRegressionTests` protects the non-rendered semantic contract: spoken structural state, Item Identifier vs Index Path behavior, locale-aware number/date formatting, domain-informed sizing invariants, and locale-invariant technical representations.

For the complete release checklist, including VoiceOver, Full Keyboard Access, Switch Control, and Accessibility Inspector steps, see [`ACCESSIBILITY_REGRESSION.md`](ACCESSIBILITY_REGRESSION.md).

## Localization and presentation resource design

The shared presentation-resource direction for localization, text fitting, symbology/images, semantic color, accessibility, Structure metadata, UIVocabulary, SBJLayout integration, and vendor/document/server overrides is documented in [Localization and Presentation Resources](../LOCALIZATION_AND_PRESENTATION_RESOURCES.md).

