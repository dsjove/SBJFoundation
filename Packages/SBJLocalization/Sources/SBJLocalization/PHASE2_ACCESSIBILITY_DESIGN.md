# Phase 2 — Accessibility and presentation contracts

## Boundaries

- `StringPresentable` supplies visible descriptions, abbreviated variants, and multiline candidates. It is **not** an accessibility protocol. The long-term text/resource design is documented in `LOCALIZATION_AND_PRESENTATION_RESOURCES.md`; no speculative shared text type is introduced here.
- `Accessible` is the minimal protocol for *three distinct* spoken channels: label, hint, and current value. Its nil defaults continue to let domain models adopt only the relevant channels.
- `AccessibleItem` is concrete, value-semantic metadata. `SBJPropertyInfo` and `AccessibleImageItem` now compose it rather than storing three duplicate fields. The established initializers and computed accessibility properties remain available.
- `AccessibleImage` stays separate because it adds visual image and label metadata; whether a visible label is shown (`labeled`) remains independent of spoken hint and value.
- `Alertable`/`PendingAlert` are presentation of alerts, not `Accessible` or `StringPresentable`; their string-resource migration is deferred to the proposed localized text representation.

## SwiftUI adapters

- `Localization/SBJAccessibilityModifier.swift` owns `View.accessibility(_:)` and `View.accessibility(label:hint:value:)`.
- Nil channels are not overwritten. The modifier does not derive spoken labels from abbreviated visible strings.
- Editor-specific accessibility assembly remains inside `SBJStructure/Editor`; `SBJEditorAccessibilitySemantics` owns changed/empty/invalid wording. Its modifier uses the shared `AccessibleItem` adapter. These strings are legacy literal status copy pending text-resource design.
- No Editor or SBJSubject references may be added to Localization or UIVocabulary accessibility utilities.

## Future subpackage extraction (Phase 5)

- `Accessible`, `AccessibleItem`, `StringPresentable` and the generic SwiftUI modifiers are strong candidate APIs for `Packages/SBJLocalization`.
- `SBJPropertyInfo` can move there after checking all callers and imports.
- `AccessibleImage` currently depends on `ImageReference`; extraction needs a dependency decision, not a circular import.
- `StringPresentable` extension conformances for units depend on units owned by SBJFoundation and must stay with their owning module or an adapter module.
- `PendingAlert` uses `Alertable` and SwiftUI; its localization model should be revisited before assuming that every alert is a resource-key lookup.

## Verification

- Existing initializer/API contract tests live in `SBJFoundationUtilitiesTests`, `ImageReferenceTests`, `SharedUIAPITests`, and `SBJAccessibilityLocalizationRegressionTests`.
- File moves stay in the existing SBJFoundation target for Phase 2. Existing tests are not relocated into the empty subpackage before the source migration.
