# SBJLocalization

User-facing names, descriptions, semantic symbols, accessibility metadata and reusable presentation transformations.

## Use

```swift
import SBJLocalization
```

`SBJTextPresentable` supplies textual presentation; for string-backed enums, its default description is derived by un-camel-casing the raw value. Use a model's `+Nomenclature.swift` extension for presentation conformance and named `SBJPropertyInfo` values. Supply explicit titles only when automatic naming is inadequate. `SBJPropertyInfo` is metadata for meaningful presentation rather than a duplicate of an already-readable name.

`SBJSymbology` and `SBJSymbol` represent semantic symbols. Accessibility helpers and string/presentation transformations are also in this module. Refer to the public declarations for platform-specific modifiers.

## Dependencies

This package has no local SBJ package dependency. It does not require editor, file, document, or unit infrastructure.

## Tests

Behavioral tests should cover transformations, omission/formatting rules and accessibility semantics—not copies of literal strings or uncomplicated property accessors.

## Property accessibility defaults

`SBJPropertyInfo.accessibility` resolves explicit accessibility annotations with presentation metadata as fallbacks:

```swift
let info = SBJPropertyInfo(title: "Attunement", summary: "Current attunement state")
let accessible = info.accessibility
// AccessibleItem(label: "Attunement", hint: "Current attunement state")
```

An explicit `accessibilityLabel` overrides `title`; an explicit `accessibilityHint` overrides `summary`. Missing values remain `nil`. `details` is **never** automatically spoken as a hint. The stored fields remain unchanged, so callers can distinguish explicitly provided accessibility annotations from derived defaults. Runtime accessibility values still come from `SBJTextPresentable`.

### Test coverage (2026-10-29)

The Swift Testing suite covers `SBJPropertyInfo` accessibility fallback and overrides, `AccessibleItem`, `SBJTextPresentable`, symbol lookup and fallback (`exclamationmark.questionmark`), symbol emptiness and bundled resource lookup, presentation lists, jargon overrides and typed formatting, and number formatting. Removed symbols such as `AccessibleSymbolItem` and `.missing` are intentionally not referenced. Run the suite using the Apple SDK in Xcode; a Linux syntax parse is not an Apple-platform test run.
