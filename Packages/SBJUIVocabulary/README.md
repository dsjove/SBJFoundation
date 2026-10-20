# SBJUIVocabulary

Shared UI vocabulary: appearance, buttons (including the unified SBJURLButton), colors, fields/sizing, fonts, menus, and view utilities.

## Dependencies
SBJDataDefinition, SBJLocalization, and SBJFileResources. SBJURLButton retains the existing `URL.open()` and `isValidURL` behavior from SBJFileResources; it does not use SwiftUI `openURL`.

The editor-only TODO comments remain for later review. `SBJDeleteButton` is intentionally outside this package and unchanged in this pass.
