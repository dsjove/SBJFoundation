# Jove's Characters / CharacterSheet — localization notes

**App-specific guidance retained and updated from the prior `Localization.md`.** This is a consumer-level design document; it is not evidence that the future localization resolver has been implemented.

## Current ownership

- `Character` domain `+Nomenclature.swift` extensions may conform to `SBJTextPresentable` for **reusable** character-game vocabulary (`presentedValue`, `abbreviation`, `multiLineDescription`). They should not contain diagnostic dump descriptions or adopt a protocol just to satisfy UI calls.
- `CharacterSheet/Sources/presentation/**/+Presentation.swift` owns **sheet-specific** wording: compact attack rows, spell/resource summaries, movement/senses aggregation, inventory rows and multiline sections. A sheet-only presentation should not be pushed into a domain conformance.
- `SBJPropertyInfo` declares property meaning and help/accessibility labels and hints, not current values. `accessibilityValue` is `String?` on `SBJTextPresentable`, defaults to `nil`, and should be implemented only if it improves spoken output over system-provided accessibility.
- User-supplied character/campaign names, descriptions, notes and imported content are verbatim unless explicitly identified as localizable semantic resources.

## Audit rules

For every former `description` implementation, ask whether it is useful shared text (`presentedValue`), exclusively CharacterSheet display (`+Presentation`), a real persisted domain property named `description` (leave intact), or a diagnostic dump (delete rather than add `CustomDebugStringConvertible`). Do not mechanically replace numeric/dice `description` or unrelated Swift `description` with `presentedValue`. Do not assume `String` conforms to the presentation protocol. Keep optional values absent unless the sheet deliberately needs a placeholder.

## Future context-aware migration

D&D vocabulary is rules/edition/campaign-sensitive. Attack DC and bonus construction, timing/damage phrasing, spell-slot wording, unit measurement, currencies and quantities must eventually use complete localized templates with typed inputs, not English fragment concatenation or lowercasing translated words. Preserve independent sheet `standard`/`compact`/`abbreviated` candidates and layout-dependent fit policy. Spoken output should be governed by `AccessibilityContext` (view use), not model boilerplate.

See [README.md](README.md) for current contracts and [LAYERED_CONTEXT_AWARE_LOCALIZATION.md](LAYERED_CONTEXT_AWARE_LOCALIZATION.md) for the desired shared architecture.
