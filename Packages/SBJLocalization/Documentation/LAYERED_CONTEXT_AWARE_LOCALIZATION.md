# Desired design — layered, context-aware localization

**Design proposal, not implemented.** This records the intended direction without turning provisional concepts into claims about current APIs. The full resource/resolver shape, precedence, and naming require design and tests.

## Purpose

Localization is not only translating a string by language. A user-facing concept can depend on language and locale; app/vendor branding; D&D rules edition; document/campaign terminology; server-provided policy; the actual instance; current view/presentation use; space and typography; accessibility preferences; grammatical case/number/gender; and whether content is user-authored and must remain verbatim.

The system must retain semantic identity and typed values until sufficient context is available to resolve presentation. Do not compose translated phrases by translating English fragments or substituting words in finished text.

## Layers and responsibilities

1. **Declaration localization — `SBJPropertyInfo` (present):** compile/build-time-authored descriptions of *what the property is*: title, summary, details, symbol, accessibility label and hint. A declaration can be localized later but cannot know an instance's runtime value. It must not contain `accessibilityValue`.
2. **Runtime value localization — `SBJTextPresentable` (present, limited):** `presentedValue`, `abbreviation`, `multiLineDescription`, optional `accessibilityValue: String?`. A value may supply domain-specific visible/spoken forms. No automatic `accessibilityValue` fallback: `nil` means no custom value. Longer-term, these plain strings may become context-resolved, typed resources rather than eager text.
3. **Localization resolution context — proposed:** locale, cultural formatters, vocabulary providers and sparse overrides (framework → app/vendor → document/rules/settings where appropriate), typed grammatical inputs, intentional verbatim content, and resolution policy. Exact precedence must be specified per resource class; blindly using a single override chain is risky.
4. **`AccessibilityContext` / accessibility use — proposed:** *the context of how a resolved value is used on this view*. A field label, selected menu option, interactive slider, static display, heading, image, and document/PDF element may require different announcements. It combines declaration meaning and instance value with the view's role and behavior. **This is not another property on `SBJPropertyInfo` and not a mandatory protocol conformance on models.** Traits, custom actions, grouping, focus, reading order and other view semantics belong to this context or UI infrastructure, not blindly on domain values. Exact API and representation are deferred.
5. **Layout/presentation context — proposed:** font, available bounds, writing direction, wrapping/line limits, style, and whether full/compact/abbreviated candidates fit. SBJLayout measures and renders, not translates.

## Desired resolution flow

```text
Semantic property declaration (`SBJPropertyInfo`) ─┐
                                                   ├─> localization/resource resolution
Concrete instance (`SBJTextPresentable` if useful) ─┤       (locale, grammar, app/vendor/document overrides)
                                                   │
Context of use (`AccessibilityContext`, view role) ─┤
Layout constraints and presentation policy ─────────┘
                          ↓
           visible candidate(s) + appropriate spoken semantics
                          ↓
                 SwiftUI / UIKit / PDF rendering
```

`AccessibleItem` is today's small assembled container for label/hint/value, assembled by `SBJStructured.accessibilityItem(for:)`. It is **not** the final representation of accessibility traits, actions or context. The view should preserve framework-derived accessibility unless there is a meaningful override. The user's phrase **AccessibilityUse** describes this view-specific concern; **AccessibilityContext** is a proposed explicit carrier for it, not a settled API name.

## Semantic resources and localization candidates (future)

- Prefer source-string-based, String Catalog-extractable inputs rather than a global enum of thousands of keys. Verify Xcode extraction before committing to wrappers; `LocalizedStringResource` may be a useful underlying mechanism.
- Distinguish framework/app-owned localizable text, verbatim user/server text, typed formatted inputs, and system-owned accessible UI semantics.
- Support independently authored `standard`, `compact`, and `abbreviated` translations rather than mechanically abbreviating translated prose; multiline may be a separate authored candidate, not simply newline insertion.
- Keep semantic symbols/images and semantic colors available for theme/contrast/RTL/cultural selection; do not reduce them prematurely to an SF Symbol name or raw color.
- Make overrides sparse and composable where justified; preserve the identity of a resource rather than replacing substrings in resolved sentences.
- Preserve grammar and typed interpolation until translation and formatting. Measurements, currency, counts, dice, dates, and phrases should not be English-only concatenations.
- Resolve visible and spoken output independently when necessary. A visual abbreviation may need a fuller spoken form; conversely many SwiftUI controls already synthesize the correct accessible value.

## Optional semantics

Optional data is not synonymous with the spoken word “none.” On absent instance values, default runtime spoken content should remain absent. An editor may explicitly announce “Not selected,” while a read-only sheet may omit the field entirely. That decision belongs to use/context, not blanket `Optional` stringification.

## Boundaries / intentionally deferred

- No universal context API, override ordering, resource type, or catalog implementation is finalized.
- No migration of all hardcoded strings is implied by current `SBJTextPresentable` renames.
- No new automatic accessibility labels/values are introduced just because metadata exists.
- `AccessibilityContext` still needs design for traits, actions, focus, grouping and UI ownership; consult platform accessibility behavior before replacing it.
- `Jargon` is prototype code, not a commitment to its interface.

## Acceptance criteria for the future design

Demonstrate correct locale/grammar output; independent compact and spoken text; extraction into String Catalogs; verbatim user content; app/vendor/document overrides; deterministic layout fitting; absence handling; and VoiceOver behavior on standard and custom controls. Validate through CharacterSheet (dense layout) and an ordinary app form before broad migration.
