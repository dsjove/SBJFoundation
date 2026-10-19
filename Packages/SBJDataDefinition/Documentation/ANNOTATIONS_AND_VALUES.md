# Data annotations and value semantics

The `@SBJStructure` and property metadata annotations are declared in SBJDataDefinition. `@SBJEditable` is an SBJFoundation umbrella macro that includes structural generation. Editor-specific annotations are declared in SBJFoundation.

# Annotation reference

## `@SBJStructure`

Attaches structural metadata generation to a `Codable` struct or enum.

For structs:

- coded stored properties become structural metadata;
- writable coded properties become generic editor fields;
- immutable coded properties remain structural but are not editable;
- writable computed properties remain outside the structure unless explicitly marked `@SBJEditorProperty`.

For enums, associated-value case metadata is generated for recursive editing and source export.

## `@SBJString`

Adds String length constraints and/or text presentation.

```swift
@SBJString(minLength: 1, maxLength: 40)
@SBJEditorString(.singleLine)
var name: String

@SBJString(maxLength: 2_000)
@SBJEditorString(.multiline)
var notes: String
```

Parameters:

- `.singleLine` / `.multiline`
- `minLength`
- `maxLength`

## `@SBJInteger`

Adds an integer closed-range or minimum constraint.

```swift
@SBJInteger(range: 1...24)
var servings: Int

@SBJInteger(min: 0)
var experience: Int
```

## `@SBJNumber`

Adds a floating-point closed-range or minimum constraint.

```swift
@SBJNumber(range: 0...1)
var opacity: Double

@SBJNumber(min: 0)
var scale: Double
```

Non-finite values fail generated range/minimum validation.

## `@SBJOptional`

Adds an optional presence requirement.

```swift
@SBJOptional(required: true)
var owner: Owner?
```

The requirement is checked only during explicit validation.

## `@SBJArray`

Adds array constraints and usage hints.

```swift
@SBJArray(reorderable: true, minCount: 1, maxCount: 10, uniqueBy: \RecipeIngredient.id)
@SBJEditorArray(title: \RecipeIngredient.name)
var ingredients: [RecipeIngredient]
```

Parameters:

- `reorderable` — whether a consumer may expose stored-order changes.
- `title` — element key path used for human-readable item presentation.
- `minCount`
- `maxCount`
- `unique` — requires Hashable elements to be unique.
- `uniqueBy` — uniqueness by a Hashable element key path and a natural stable identity source for editor collection items.

`unique` and `uniqueBy` are mutually exclusive. Arrays always preserve stored order; `reorderable` does not imply sorting.

## `@SBJSet`

Adds Set count constraints and item-title metadata.

```swift
@SBJSet(minCount: 1, maxCount: 20)
@SBJEditorSet(title: \Proficiency.name)
var proficiencies: Set<Proficiency>
```

Sets have no stored ordering, so the stock editor presents them deterministically rather than offering reordering.

## `@SBJDictionary`

Adds dictionary entry-count constraints.

```swift
@SBJDictionary(minCount: 0, maxCount: 20)
var modifiers: [String: Int]
```

The generic editor stages key renames and rejects collisions instead of overwriting another entry.

## `@SBJDate`

Adds a `Date` range invariant.

```swift
@SBJDate(range: earliestAllowed...latestAllowed)
var modified: Date
```

A plain `Date` already receives the built-in date editor. The range is validation metadata, not a `DatePicker` input restriction.

## `@SBJURL`

Adds broad URL-kind constraints.

```swift
@SBJURL(allowed: [.file])
var sourceFile: URL

@SBJURL(allowed: [.network])
var serviceURL: URL
```

`.file` accepts file URLs. `.network` accepts absolute non-file URLs with a scheme. Relative URLs belong to neither category.

A plain URL needs no annotation and still receives the built-in URL editor.

## `@SBJUUID`

Adds a nonzero UUID constraint.

```swift
@SBJUUID(nonzero: true)
var identifier: UUID
```

The stock editor accepts canonical, compact, and brace-wrapped UUID text, normalizes valid input, and provides UUID generation whether or not the annotation is present.

## `@SBJData`

Adds Data byte-count constraints.

```swift
@SBJData(min: 16, max: 64, modulo: 16)
var payload: Data
```

Parameters operate on bytes:

- `min`
- `max`
- `modulo`

The built-in editor presents Data as multiline hexadecimal and does not mutate the model while textual input is incomplete or invalid.

## `@SBJColor`

Adds usage information to `CodableColor`.

```swift
@SBJColor(alpha: false)
var accent: CodableColor
```

A plain `CodableColor` already uses the built-in color editor. `alpha: false` tells consumers to treat the value as RGB-only.

## `@SBJDesignatedInit`

Marks the initializer used as the source-of-truth reconstruction path for Swift source export. See [Swift source export and designated initialization](#swift-source-export-and-designated-initialization).

---

# Unannotated built-in values

Unannotated coded values are the normal case. Built-in scalar editing currently includes:

- `String`
- `Bool`
- signed and unsigned fixed-width integers
- `Float`
- `Double`
- `CGFloat`
- `Decimal`
- `Date`
- `URL`
- `UUID`
- `Data`
- `CodableColor`

`CodableFont` is itself an `@SBJStructure` model and additionally receives specialized font-family editing. It stores family/system font choice, point size, weight, italic state, and width, and can realize cached or uncached platform fonts through `CodableFontCache`.

Known value types use their ordinary `Equatable` behavior as structural leaves where appropriate.

---

# Reusable value utilities

Operations used by the stock editor are public when they are useful independently of the editor.

## Hexadecimal Data

```swift
let text = data.sbjHexFormat(bytesPerRow: 16)
let parsed = try text.sbjHexData()
```

`Data` provides `sbjHexDescription`, `sbjHexFormat(...)`, and `isZero`. `String` provides throwing `sbjHexData()` and optional `sbjHexToData()` parsing.

## URL and UUID parsing

```swift
let url = " https://example.com ".sbjURL
let uuid = "550E8400E29B41D4A716446655440000".sbjUUID
```

These are the same parsing rules used by the stock scalar editors.

## Safe collection mutation

```swift
var names: Set = ["one", "two"]
names.sbjReplace("one", with: "three")

var values = ["one": 1, "two": 2]
values.sbjRenameKey("one", to: "three")
```

Both operations reject collisions and leave the collection unchanged on failure.

## Codable copying and encoded fallback comparison

```swift
let snapshot = edited.sbjCodableCopy()
let encodedDifference = edited.sbjEncodedIsDifferent(from: original)
```

`sbjCodableCopy()` is useful for independent snapshots. Encoded comparison remains available as a public utility and as the structural-comparison fallback for opaque Codable values, but generated SBJ structures normally use field-by-field structural comparison.

---

# Public API organization

SBJStructure favors APIs that are discoverable from the value they operate on. General operations on `Data`, `String`, collections, and Codable values are public `sbj`-prefixed extensions.

Namespace/service types remain where there is no natural primary receiver or where the operation represents a service family:

- `SBJInvariantCheck` — explicit invariant evaluation.
- `SBJContentCheck` — recursive content inspection.
- `SBJStructuralCompare` — generic structural-equivalence dispatch.
- `SBJStructureDiagnostics` — UI-independent model diagnostics.
- `SBJEditorDiagnostics` — editor-specific diagnostics.
- `SBJDefaultValue` — type-erased context-free creation.
- `SBJEditorRegistry` — application editor/creator overrides.
- `SBJSwiftEncoder` — Swift source reconstruction.

---

# What the framework intentionally does not do

SBJStructure does not:

- wrap annotated stored properties;
- validate on every assignment;
- force a throwing or failable initialization policy;
- treat `Equatable` as structural persistence equality for generated structures;
- treat `.isEmpty` as universal content semantics;
- require a parallel builder/schema declaration;
- require the generic editor to use the structural model;
- require a particular scrolling/container UI;
- make editor-only computed properties part of persistence automatically;
- turn validation constraints into input restrictions.

Those omissions are design decisions, not missing enforcement.

---

# Package requirements

The current package uses Swift tools 6.4 and declares:

- iOS 17+
- watchOS 10+

The SwiftUI editor is `@MainActor` where appropriate; structural metadata and model operations remain usable independently of SwiftUI.



## System accessibility appearances

The generated editor treats system accessibility appearance preferences as part of its presentation contract, not as application-specific polish. Its chrome uses semantic system colors and preserves meaning independently of color.

- **Increase Contrast** strengthens borders, focus rings, hierarchy cues, and validation outlines.
- **Differentiate Without Color** adds a non-color selection cue to the editor's Changed/Empty filters; row state already uses distinct pencil and dashed-rectangle symbols rather than color alone.
- **Reduce Transparency** removes translucent validation/header fills where they are not necessary and relies on opaque outlines and structural cues instead. Focus shadows are suppressed.
- **Light and Dark appearance** use semantic foreground/background styles rather than fixed RGB presentation colors.
- Color filters should not erase meaning because changed, empty, invalid, disclosure, and selection states have shape/symbol/border cues in addition to color.

The Recipe previews include variants for increased contrast, Differentiate Without Color, Reduce Transparency, and dark increased-contrast appearance so these behaviors can be checked while the structural example remains the same.


### Keyboard, focus, and accessibility navigation

The generated editor uses native SwiftUI controls so Full Keyboard Access, Tab/Shift-Tab traversal, menus, toggles, text fields, and buttons retain platform behavior. SBJStructure adds structural semantics around those controls:

- The interactive field control owns the property's accessibility label; the separate visual label is hidden from VoiceOver to avoid duplicate stops.
- Changed, no-content, and invalid state are folded into the control's spoken label when present.
- Plain disclosure headers are one semantic accessibility target with an Expanded/Collapsed value. The decorative disclosure glyph is hidden from VoiceOver in that case; promoted editable headers keep the disclosure control separately accessible.
- Collection remove and reorder actions have explicit labels and action hints.
- Stable `SBJEditorItemIdentifier` values continue to drive SwiftUI item identity while `SBJEditorIndexPath` represents current position, so reordering preserves the logical view/control identity whenever SwiftUI can preserve focus.
- Programmatic focus after creating optional values or collection elements continues to use `SBJEditorFocusRequest`; normal keyboard focus remains owned by the native control.

Menu-backed scalar editors use one compact presentation: the selected value followed by a small up/down chevron. This keeps prototype editors dense while preserving an explicit menu affordance and native keyboard/menu behavior.

Use macOS/iPadOS Full Keyboard Access, VoiceOver, Switch Control, and Accessibility Inspector as behavioral tests; these cannot be fully simulated by static SwiftUI previews.


### Accessibility and localization regression harness

The canonical sample model is also the framework's accessibility/localization regression surface. The automatic and standalone editor previews plus integration tests all exercise that one fixture rather than maintaining separate preview-only or test-only models.

The preview matrix covers default and dark appearance, large Dynamic Type, a narrow AX5 layout, French and German locales, Arabic right-to-left presentation, and a deliberately changed/empty/invalid model state. System settings that are read-only SwiftUI environment values on the supported target (including Increase Contrast, Differentiate Without Color, and Reduce Transparency) are verified through Xcode Environment Overrides / Accessibility Inspector.

`SBJAccessibilityLocalizationRegressionTests` protects the non-rendered semantic contract: spoken structural state, Item Identifier vs Index Path behavior, locale-aware number/date formatting, domain-informed sizing invariants, and locale-invariant technical representations.

For the complete release checklist, including VoiceOver, Full Keyboard Access, Switch Control, and Accessibility Inspector steps, see [`ACCESSIBILITY_REGRESSION.md`](ACCESSIBILITY_REGRESSION.md).

## Localization and presentation resource design

The shared presentation-resource direction for localization, text fitting, symbology/images, semantic color, accessibility, Structure metadata, UIVocabulary, SBJLayout integration, and vendor/document/server overrides is documented in [Localization and Presentation Resources](../LOCALIZATION_AND_PRESENTATION_RESOURCES.md).

### Content semantics and future empty-value annotations

`hasContent` represents meaningful stored content, not whether a scalar is nonzero
or truthy. Strings and collections aggregate their contents; optionals are empty
when `nil` and otherwise follow their wrapped value; structs aggregate members;
plain enum cases and scalar values always have content; associated-value enum
cases aggregate their associated values. Explicit `HasContentCheckable` behavior
takes precedence over these defaults. Dictionary values, rather than just the
presence of keys, determine dictionary content.

**Future feature (not implemented):** consider an `@SBJEmptyValue(...)`
annotation for individual scalar/POD properties when a domain-specific sentinel
(e.g. `0`, `false`, or a particular enum case) intentionally means *empty*.
This would be opt-in, scoped to a property, and must not change the default
semantics for scalar values throughout the framework.
