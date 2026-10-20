# SBJLocalization

User-facing names, descriptions, semantic symbols, accessibility metadata and reusable presentation transformations.

## Use

```swift
import SBJLocalization
```

`StringPresentable` supplies textual presentation; for string-backed enums, its default description is derived by un-camel-casing the raw value. Use a model's `+Nomenclature.swift` extension for presentation conformance and named `SBJPropertyInfo` values. Supply explicit titles only when automatic naming is inadequate. `SBJPropertyInfo` is metadata for meaningful presentation rather than a duplicate of an already-readable name.

`SBJSymbology` and `SBJSymbol` represent semantic symbols. Accessibility helpers and string/presentation transformations are also in this module. Refer to the public declarations for platform-specific modifiers.

## Dependencies

This package has no local SBJ package dependency. It does not require editor, file, document, or unit infrastructure.

## Tests

Behavioral tests should cover transformations, omission/formatting rules and accessibility semantics—not copies of literal strings or uncomplicated property accessors.
