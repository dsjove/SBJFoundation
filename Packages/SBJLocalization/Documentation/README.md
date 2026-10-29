# SBJLocalization — current implementation

**Status:** This describes the implemented APIs in SBJFoundation after the the current implementation runtime-localization refactor, not the proposed context-aware resource system. The package-level `README.md` is separate; this is the documentation-directory entry point.

## Responsibilities today

`SBJLocalization` provides declaration-site property text metadata (`SBJPropertyInfo`), runtime presentation (`SBJTextPresentable`), assembled accessibility metadata (`AccessibleItem`), SwiftUI application of accessibility metadata, semantic symbols (`SBJSymbol`, `SBJSymbology`), and text helpers. It does **not** currently implement a full locale-/vendor-/document-/layout-context resolver or alternate localized-resource candidate selection.

| Layer | Type / API | Actual responsibility |
| --- | --- | --- |
| Property declaration | `SBJPropertyInfo` | `title`, `summary`, `details`, `symbol`, `accessibilityLabel`, `accessibilityHint`; `.accessibility` resolves label as `accessibilityLabel ?? title` and hint as `accessibilityHint ?? summary`; no instance value |
| Runtime model value | `SBJTextPresentable` | `presentedValue`, `abbreviation`, `multiLineDescription`, optional `accessibilityValue` |
| Combined result | `AccessibleItem` | Optional label, hint and value |
| Structured property access | `SBJStructured.accessibilityItem(for:)` in **SBJDataDefinition** | Combines property info and runtime presentation for a key path; returns `nil` when neither source exists |
| SwiftUI | `View.accessibility(_ item: AccessibleItem?)` | Applies only non-`nil` channels, leaving other framework accessibility behavior alone |

## Runtime presentation

```swift
public protocol SBJTextPresentable {
    var presentedValue: String { get }
    var abbreviation: String { get }
    var multiLineDescription: String { get }
    var accessibilityValue: String? { get }
}
```

Current defaults: `abbreviation` is `presentedValue`; `multiLineDescription` replaces spaces in `presentedValue` with newlines; `accessibilityValue` is **`nil`**, never inferred from display text. String-backed `RawRepresentable` conformers have an un-camel-cased `presentedValue` default. These are current convenience behaviors, **not** the future context-aware localization policy. `SBJTextPresentable` replaces the removed `StringPresentable` and `AccessibilityValues` protocols; `Accessible` is also gone. Ordinary `CustomStringConvertible.description` and domain properties genuinely called `description` are distinct.

## Property metadata and accessibility

`SBJPropertyInfo` describes a declaration; it never contains or derives the current property value. Its `accessibility` accessor defaults the spoken label to `title` and hint to `summary` only when the explicit corresponding field is `nil`. It never uses `details` as a hint, and it does not modify the stored metadata. Use generated `@SBJPropertyInfo` / `@SBJStructure` key-path lookup where applicable.

```swift
// model is SBJStructured and its property has declaration metadata
let item: AccessibleItem? = model.accessibilityItem(for: \.length)
view.accessibility(item)

// For UnitValue itself:
unitView.accessibility(value.accessibilityItem(for: \.unit))
```

The assembler checks whether the **value conforms to `SBJTextPresentable`**; if its optional `accessibilityValue` is `nil`, no custom spoken value is supplied. It does not use `presentedValue`, `description`, `String(describing:)`, or invented words for missing optionals. The `nil` return condition is *neither property metadata nor value conformance*; metadata-only results are possible. `AccessibleItem.isEmpty` can separately indicate whether any accessibility channel actually contains text. Automatic SwiftUI accessibility remains the default: do not duplicate a visible `Text` value or a standard control's spoken state.

## Other implemented facilities

`SBJSymbol` and `SBJSymbology` are semantic symbol vocabulary, not a complete context-driven resource selection engine. `Jargon`/`JargonFormatter` are existing prototype APIs, **not** the proposed production resolver. `presentationList`, `presentationNotes`, `bulleted`, and related string utilities currently flatten to `String`; they do not localize composed grammar.

## Ownership and consumers

- **SBJLocalization:** property metadata, runtime presentable vocabulary, symbols, assembled accessibility data, SwiftUI adapters.
- **SBJDataDefinition:** structure metadata, generated key-path lookup, structural accessibility assembly.
- **SBJLayout / CharacterSheet:** measure, render, and select presentation in the context of layout; they should not define the shared translation policy.
- **Apps:** domain terminology and user-authored content decisions. User-entered strings are verbatim by default.

See [LAYERED_CONTEXT_AWARE_LOCALIZATION.md](LAYERED_CONTEXT_AWARE_LOCALIZATION.md) for the *proposed*, not-yet-implemented system; [Character-specific guidance](CHARACTERS_LOCALIZATION.md), [SBJLayout guidance](SBJLAYOUT_LOCALIZATION.md), and [dated audit](LOCALIZATION_AUDIT_2026-09-17.md).
