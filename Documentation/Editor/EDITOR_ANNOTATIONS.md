# Editor-specific annotations

These annotations belong to **SBJFoundation**, not SBJDataDefinition.

## `@SBJEditorExclude`

Suppresses generic editor generation while retaining structural membership.

```swift
@SBJEditorExclude
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

## `@SBJEditorFontFamily`

Adds editor-neutral presentation semantics to a structural property. Presentation metadata does not alter storage, Codable behavior, validation, or assignment semantics.

The current presentation option is font-family selection for an optional String, where `nil` represents the platform/system family:

```swift
@SBJEditorFontFamily
var family: String?
```

Presentation hints are not invariants and may be ignored by non-UI consumers.

