## Accessibility and cultural adaptation

The stock editor is meant to be useful as a real prototyping surface, so accessibility and locale behavior are part of its layout contract rather than a finishing pass.

Text uses semantic system styles (`body`, `caption`, `headline`, and related styles) so it participates in Dynamic Type. Text-bearing controls use **minimum** heights rather than fixed heights; larger fonts are allowed to make the row taller. Compact controls may still have minimum hit/visual dimensions where appropriate, but those minima do not cap text growth.

Scalar editors also use structural constraints to avoid the opposite failure mode where every control stretches across the entire window. For example:

```swift
@SBJInteger(range: 1...24)
var servings: Int
```

The editor knows that `servings` is a small-domain numeric value. It therefore chooses a compact preferred width, but that width scales with Dynamic Type and is calculated from locale-formatted boundary values. It is a preference, not a rigid point-size assumption.

Human-facing numeric and date input follows the environment locale. `Int` and floating-point editors use Foundation format styles; the smaller fixed-width integer editors (`Int8` through `UInt64`) use locale-aware formatting and parsing rather than exposing `LosslessStringConvertible`'s machine representation; `Decimal` uses a locale-aware decimal formatter for both parsing and display; and `DatePicker` follows the system's locale/calendar behavior. Human-facing counts and percentages in editor chrome are formatted through the current locale as well. Technical representations such as UUIDs, URLs, hexadecimal Data, and serialized source remain intentionally locale-invariant.

This boundary is deliberate: **localize presentation, not storage**. A `Decimal`, `Date`, or integer remains the same model value regardless of the user's locale. The editor is responsible for accepting and presenting the punctuation and conventions appropriate to that user. Conversely, values whose meaning is their technical representation—UUID strings, URLs, and hexadecimal bytes—must not change simply because the UI locale changes.

`SBJStructuredEditorPreview` uses the canonical sample model in `Preview/SBJStructureSampleModel.swift`, which keeps the same **Meal Recipe** domain as this README, and includes dedicated previews for:

- the default environment;
- a large accessibility Dynamic Type size;
- a French locale, exercising decimal/date punctuation;
- right-to-left layout direction.

The point of those previews is not to create separate locale-specific layouts. SBJStructure prefers semantic leading/trailing alignment, intrinsic content size, and layouts that adapt to the content they receive.

