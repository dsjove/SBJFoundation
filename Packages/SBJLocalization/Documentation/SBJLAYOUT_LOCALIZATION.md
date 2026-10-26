# SBJLayout — localization and fitting responsibilities

**Client-specific design retained and updated from `LOCALIZATION_DESIGN.md`.** The proposed shared resource resolver and candidate selection are not implemented.

SBJLayout owns font- and bounds-aware measuring, wrapping, line limits, text fitting, PDF layout, and consistency between measured and drawn candidate. `TrackElement.minimumMeasure(bounds:)` is a geometry primitive, **not** translation or localization resolution.

SBJLayout must **not** own app vocabulary catalogs, vendor or rules-variant terminology, grammatical translation, `SBJTextPresentable` implementations for Character models, or automatic English abbreviation generation.

The older `JCSText` paths (raw `CustomStringConvertible.description`, `Jargon` lookup, explicit verbatim text) demonstrate why early flattening is problematic. `Jargon` is a prototype; do not make it the final localization API merely because existing rendering code knows it. Future `JCSText` should be able to accept already-semantic/typed localized resources with authored candidates, alongside explicitly verbatim strings. Details await the common context-aware resolver and String Catalog extraction tests.

Accessibility in PDF/layout output needs the use context: document role, hierarchy, reading order and what visible abbreviations mean aloud. That is a future `AccessibilityContext` responsibility, not an instance-level `accessibilityValue` invented for every value.

See [LAYERED_CONTEXT_AWARE_LOCALIZATION.md](LAYERED_CONTEXT_AWARE_LOCALIZATION.md).
