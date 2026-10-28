# Editor-specific annotations

These annotations belong to **SBJFoundation**, not SBJDataDefinition.

## `@SBJFieldPresentation(exclude: true)`

Suppresses generic editor generation while retaining structural membership.

```swift
@SBJFieldPresentation(exclude: true)
var generatedSummary: String
```

The property remains in `sbjProperties`, content inspection, structural comparison, and invariant validation.

## `@SBJEditorProperty`

Adds a writable computed property to generic editing **without** making it structural.

```swift
@SBJEditorProperty
var platedPhoto: PlatformImage? {
    get { imageStore.load(identifier) }
    set { imageStore.stage(newValue, id: identifier) }
}
```

Editor-only properties:

- appear in `sbjEditorFields`;
- do not appear in `sbjProperties`;
- do not participate automatically in generated content semantics, structural equality, or invariants;
- do not need to conform to `Codable`.

This distinction is intentional: editability and structure are separate concerns.

## Font-family values

Font-family selection is determined by the property type, not an editor annotation.
Declare a `FontFamily?` property to present the font-family picker. `nil` denotes
the system font:

```swift
var family: FontFamily?
```

`FontFamily` is string-literal-initializable and normalizes names on ordinary
initialization. Its `Codable` conformance is synthesized.
