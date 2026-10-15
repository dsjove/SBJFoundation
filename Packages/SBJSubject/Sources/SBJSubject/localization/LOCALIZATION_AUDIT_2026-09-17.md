# Localization / Presentation Audit — 2026-09-17

## Design baseline

This audit uses the current shared proposal in `SBJFoundation/Documentation/LOCALIZATION_AND_PRESENTATION_RESOURCES.md` and the application design in `Jove-s-Characters/Jove's Characters/Documentation/Localization.md`.

The important consequence is that **this is an inventory, not a blind string-wrapper migration**. `SBJTextResource` is not implemented yet. The agreed first source shape is an initializer whose argument is `LocalizedStringResource`, with explicit verbatim construction, typed interpolation, `standard` / `compact` / `abbreviated` candidates, and resolution through an `SBJPresentationContext` plus sparse providers. Until that API exists and the Xcode String Catalog extraction fixture is proven, existing SwiftUI literals should remain SwiftUI literals rather than being moved into a temporary parallel localization system.

The audit also preserves these boundaries:

- persisted identifiers, schema names, defaults keys, file extensions, protocol/wire tokens, and user-authored text are **not** localization resources;
- image vocabulary is semantic presentation, but symbol choice is not text localization and should remain behind `ImageReference`/semantic image vocabularies;
- accessibility copy is related presentation copy and should migrate with the same semantic property/action, not as independently concatenated fragments;
- units remain semantic model values; localized names, abbreviations, number formatting, and compound presentation belong in the future shared presentation resolver;
- server/vendor/document terminology overrides operate on resource/semantic identity, never by substring replacement of resolved prose.

## Mechanical inventory

Counts below exclude tests and generated/package metadata. They are migration-seam counts, not defect counts. A literal may already be correctly typed for Apple String Catalog extraction today.

| Component | Swift files | UI literals | Accessibility literals | `SBJPropertyInfo` construction | `StringPresentable` refs | Raw system-image UI refs | `LocalizedError` refs | Catalogs |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| SBJFoundation | 255 | 78 | 3 | 44 | 11 | 1* | 6 | 0 |
| SBJLayout | 41 | 3 | 4 | 0 | 0 | 0 | 0 | 0 |
| SBJLego | 19 | 1 | 0 | 0 | 0 | 0 | 0 | 0 |
| BLEByJove | 28 | 1 | 0 | 0 | 0 | 0 | 0 | 0 |
| SbjGauge | 45 | 12 | 0 | 0 | 0 | 0 | 0 | 0 |
| Jove's Pieces | 17 | 10 | 3 | 0 | 0 | 3 | 0 | 0 |
| Jove's TODOs | 17 | 33 | 12 | 0 | 0 | 23 | 0 | 0 |
| Jove's Meals | 74 | 42 | 6 | 0 | 0 | 10 | 0 | 0 |
| Jove's Characters | 187 | 60 | 3 | 0 | 102 | 2 | 3 | 0 |
| Jove's Photo Msg | 27 | 11 | 4 | 0 | 0 | 7 | 2 | 0 |
| Jove's Landing | 53 | 30 | 0 | 0 | 0 | 10 | 0 | 0 |

`*` SBJFoundation's raw system-image matches are renderer/conversion implementation inside `ImageReference`/help rendering, not bypasses of the semantic UI vocabulary.

No `.xcstrings` or `Localizable.strings` catalogs are currently present in these projects.

## Component findings

### SBJFoundation

This remains the implementation blocker and therefore the highest-priority localization component. The existing design inventory is still accurate: `StringPresentable`, `Units+StringPresentable`, `Array+bulleted`, `Jargon`, `PendingAlert`, `SBJIssue`, `Accessible`/`AccessibleImage`, `SBJPropertyInfo`, generated editor labels, and numeric editors are the important seams.

The recent Image / Attachments / Tags / Units work is directionally correct: semantic imagery is now separated by domain and accessibility metadata is associated with model/property information. Do not convert that metadata to ad-hoc localized `String` lookups; migrate `SBJPropertyInfo` once the shared text-resource type exists.

`ColorPickerView` versus `SwiftUI.ColorPicker` remains explicitly unresolved and is not a localization issue. `CameraPickerView` duplication with SBJCamera is also explicitly unresolved.

### SBJLayout

Keep layout independent of localization lookup. Its role is to measure and choose among already unresolved/localizable presentation candidates using geometry, font, and fitting constraints. The current `Renderable` localization/fitting TODO remains the correct bridge point. Do not move application vocabulary or a catalog resolver into SBJLayout.

The four accessibility literals found here should eventually accept/resolve shared presentation resources where they are framework-owned; geometry/debug strings remain verbatim.

### SBJLego

Very small text surface. Most values are device/protocol concepts rather than general UI copy. Defer migration until SBJFoundation text resources exist; classify BLE/device identifiers and command text as verbatim unless they are explicitly shown as app-owned labels.

### BLEByJove

Wire protocol values, UUIDs, command tokens, device names received from hardware, and diagnostic descriptions are not localization resources. The small UI-facing surface can migrate later through the shared resource type. Do not localize serialization/debug representations.

### SbjGauge

Gauge labels are presentation clients but the framework should not own application terminology. Static framework instructions/empty states are localizable; caller-provided labels and numeric values should remain typed/verbatim inputs. Future candidate fitting is especially relevant here because compact/abbreviated text may be selected by geometry.

### Jove's Pieces

Primary localizable surface is ordinary SwiftUI copy, accessibility instructions, and domain vocabulary such as labels for sets/pieces/actions. LEGO part numbers, set numbers, user names/notes, and stored identifiers remain verbatim.

The photo migration now uses SBJFoundation `PhotoMenu`/resource-content UI and the attachment icon uses the attachment semantic vocabulary. Remaining raw image symbols are domain/navigation imagery; move them to an app vocabulary only when stable semantic reuse justifies it, not merely to eliminate `systemName:` mechanically.

### Jove's TODOs

This has the densest small-app UI/action vocabulary and accessibility surface. It is a good Phase-2 consumer after SBJFoundation text resources exist. Project/task names and notes are user-authored verbatim values; action phrases, field labels, menus, validation, and accessibility instructions are localizable.

Do not construct localized grammar from independently translated pieces (for example Add/Delete + noun). The existing Foundation TODO on grammatical action resources applies directly here.

### Jove's Meals

Recipe/source names entered by users, URLs, quantities stored as model values, and imported content are verbatim/model data. App-owned recipe workflow labels, effort/rating vocabulary, empty states, alerts, and accessibility instructions are localizable.

Unit/quantity presentation should join the shared Units + presentation-context path rather than gaining a Meals-only formatter. The deprecated generated photo thumbnail path has been removed from active UI; stored thumbnail fields remain only where schema compatibility requires them.

### Jove's Characters

This remains the largest migration client because of the 100+ `StringPresentable` references and extensive structured property information already inventoried in its localization design. Keep the existing phased plan: shared resource type first; property/accessibility metadata second; CharacterSheet/SBJLayout bridge third; then classify `StringPresentable` conformances by category.

D&D/domain abbreviations may intentionally remain English-standardized in some locales, but that must be represented as a resource/presentation decision, not by bypassing the system. User-authored character/document content remains verbatim.

### Jove's Photo Msg / SBJCamera

Status/error/action UI is localizable. Payload type identifiers, wrapper magic, UTI values, filenames supplied by users/documents, and transport metadata are verbatim. Camera hardware state strings used only for diagnostics are technical text; visible permission/error guidance is app/framework copy.

There are still two camera implementations: SBJFoundation's PhotoMenu camera path and the dedicated SBJCamera package used by Photo Msg. This is explicitly commented as unresolved and should be reconciled independently of localization and without dependency changes.

### Jove's Landing

Facility names, hardware identifiers, and dynamic model-provided labels need classification case-by-case: user/device-authored names are verbatim; app-owned controls/status vocabulary is localizable. Dynamic SF Symbol selection for hardware state is image presentation, not localization. No shared text-resource migration should begin here before the Foundation API is proven.

## Updated migration order

1. Implement `SBJTextResource`/presentation candidates in SBJFoundation using `LocalizedStringResource` input and explicit verbatim values.
2. Prove Xcode String Catalog extraction with a small build fixture before mass migration.
3. Migrate `SBJPropertyInfo`, accessibility metadata, `PendingAlert`/`SBJIssue`, and generated editor labels.
4. Add the SBJLayout bridge so localized candidates can survive through measurement and final rendering.
5. Classify and migrate Jove's Characters `StringPresentable` conformances by semantic category.
6. Integrate Units formatting/presentation through the same context.
7. Migrate application UI literals incrementally, preserving typed interpolation and distinguishing localizable grammar from verbatim model/user data.
8. Add vendor/document/server terminology providers only after resource identity is stable.

## Test policy for localization work

Do **not** snapshot or assert English copy, exact localized wording, or chosen SF Symbol names. Those tests are fragile and do not prove the localization architecture. Test contracts instead:

- a semantic resource/property/action carries a presentation resource when one is required;
- verbatim values remain verbatim through resolution;
- provider precedence and locale/context selection behave correctly;
- standard/compact/abbreviated candidate selection respects fit/accessibility policy;
- typed interpolation/formatting preserves argument meaning;
- RTL/layout and substantially longer localized fixture resources render without assuming English geometry;
- unit-system choice remains independent of locale;
- image semantic references resolve, without asserting which concrete SF Symbol currently implements them.

