# Localization and Text Presentation

## Status

This is the application-side design for the shared localization/text-presentation effort spanning Jove's Characters, SBJFoundation, and SBJLayout.

The code consolidation is complete enough that localization can now be designed against the actual recurring abstractions instead of adding another parallel string utility.

The shared localization/resource migration described here is not implemented yet. SBJLayout now has a separate minimum-content measurement primitive used by intrinsic/fill geometry; that implementation is a fitting foundation, not the localization resource/candidate system described below.

## Stringification refactor baseline (October 2026)

**Implementation status:** Model nomenclature and sheet presentation have been separated; **localization itself is not implemented** by this refactor. The current `String` outputs must not be mistaken for resolved localizable resources.

### Current code boundaries

- `Character/Sources/**/<Type>+Nomenclature.swift` supplies the model-owned `StringPresentable` descriptions, abbreviations where defined, and `SBJPropertyInfo` metadata. These are currently plain-language fallbacks and semantic help descriptions.
- `Character/Sources/**/<Type>+ComputedValues.swift` owns model calculations and rules-derived values. Do not move numerical/game-rule work into display formatting solely to make localized strings.
- `CharacterSheet/Sources/presentation/**/<Type>+Presentation.swift` supplies context-dependent, character-sheet-oriented string output (including compact forms and multiline lists). Presentation should consume model values and nomenclature, not become the source of model identity.
- `CharacterSheet` does not declare model `StringPresentable` conformances. Avoid `@retroactive` workarounds for conformances owned by `Character`.

### Refactor verification and remaining migration inventory

The October cleanup checked direct declared stored properties against `propertyInfo` cases in their matching model nomenclature extensions. `Character.rulesProfile` was added to the explicit metadata cases. This mechanical check is **not** a complete proof of metadata completeness: macro-generated members, nested models, inherited/protocol members, conditional computed properties, and descriptions' semantic accuracy still require tests or deliberate review when their implementations change.

Current `+Presentation.swift` methods were inspected for simple `description`/`abbreviation` passthroughs. None warrant deletion solely as an alias in the current set; compact and context-specific wording remains legitimate. Keep public presentation APIs stable unless call-site review establishes an alternative.

**Localization-sensitive sites to address during the future localization project (not in this patch):**

1. `CharacterSheet` attack and stat-block renderers assemble `DC`, attack bonus, damage type, timing, and dice text with interpolated punctuation and newline separators. Translate whole templates with typed arguments; do not translate interpolated final strings.
2. Lowercasing `damage.type.description` and `damage.timing.description` in attack presentation assumes English inflection and capitalization rules. Future resource APIs need grammar-aware, contextual variants.
3. `CharacterSheet` inventory weight strings use `ea`, `total`, and `/` literals; currency displays join count and denomination; spellcasting and resources join fragments using `@`, `—`, and line breaks. Treat these as localized templates and unit-formatting cases, not globally interchangeable abbreviations.
4. `multiLineDescription` and `presentationCompact` are candidates for layout-driven fitting, but retain distinct domain phrasing wherever changing line breaks alone does not preserve meaning.
5. User-supplied names, notes, descriptions, background details, and imported text remain verbatim unless their producer explicitly identifies a resource. `SBJPropertyInfo.summary/details` are developer-authored UI/help copy that will require resource resolution; they are not character data.

**No new localization resolver, resource catalogs, string keys, translated output, or language-specific fallback machinery is introduced in this effort.**

## Goals

Jove's Characters needs localization to support more than language lookup:

- normal app/editor localization and locale-aware formatting;
- compact/abbreviated/multiline wording for dense character-sheet layouts;
- future vendor/repackaged-app vocabulary;
- D&D edition/document/settings-specific terminology;
- server-provided wording with an explicit distinction between semantic/localizable content and deliberate verbatim content;
- user-authored character/campaign text that must remain verbatim;
- accessibility wording that stays understandable when visible UI uses abbreviations;
- domain formatting for measurements, dice, money, durations, bonuses, and other character data.

The app should not build a separate enum containing every localized phrase. Source-string/default-string call sites should remain the normal path.

## Framework boundary

### SBJFoundation owns

- the shared localizable/verbatim text resource representation;
- alternate candidate semantics (standard/compact/abbreviated);
- localization/override resolver contracts and context;
- UI-independent property/accessibility text metadata;
- SwiftUI/UIVocabulary adapters.

### SBJLayout owns

- preferred and minimum-content font/geometry measurement;
- candidate fitting in PDF layouts;
- line/wrap/hyphenation behavior;
- ensuring measurement and drawing use the same selected candidate.

`TrackElement.minimumMeasure(bounds:)` and `JCSText` minimum-content measurement are now implemented geometry primitives. They allow nested fill content to establish an adaptive intrinsic contribution from actual text/font/break opportunities rather than hard-coded point minima. They do not resolve localization resources or choose standard/compact/abbreviated candidates.

### Jove's Characters owns

- domain vocabulary and domain-specific candidate definitions;
- D&D-specific formatting/composition;
- document/settings terminology providers;
- any vendor configuration used by this product;
- network adapters that classify server text correctly;
- deciding which user/model values are verbatim versus semantic presentation.

## `StringPresentable` is the main migration inventory

The Character package currently has more than one hundred `StringPresentable` conformances. The protocol is not one coherent localization abstraction; it currently combines several responsibilities:

```swift
description
abbreviation
multiLineDescription
```

The default raw-String enum implementation also derives visible text from `rawValue.uncamelCased`.

This should not be mechanically renamed. Each conformance should be classified and migrated according to what it represents.

### Category 1: vocabulary/enums

Examples include abilities, skills, rules, movement modes, senses, attack metadata, alignment, identity values, and many other domain enums.

These should expose localizable source resources. Their current raw-value humanization remains a useful development fallback but is not sufficient for catalog extraction/translation.

### Category 2: abbreviations

Examples include:

- `STR`, `DEX`, etc.;
- skill marks;
- AC/stat abbreviations;
- currency abbreviations;
- measurement-unit abbreviations.

An abbreviation is not necessarily a mechanical shortening of the localized full word. It should be an independent candidate/resource where the locale/domain requires that flexibility.

Some D&D tokens may intentionally remain standardized English/domain abbreviations in many locales. That is a resource decision, not a reason to bypass the localization model.

### Category 3: alternate shape/multiline

`multiLineDescription` currently often derives a new string by replacing spaces with newlines. That is mostly layout policy and should move to SwiftUI/SBJLayout fitting where possible.

Keep a distinct text candidate only when the alternate version actually changes wording or contains translator-approved/discretionary breaks that cannot be represented as ordinary wrapping policy.

### Category 4: composed/formatted values

Many conformances build phrases from numbers, bonuses, enum descriptions, punctuation, or units. Examples include attacks, health state, spellcasting, equipment, movement, and quantities.

These should not become “localize the final interpolated String.” The future presentation should preserve typed values and localizable grammar until resolution.

### Category 5: user-authored/verbatim values

Character names, notes, backstory, campaign text, item names supplied by users, and similar content must remain verbatim unless a specific feature says otherwise.

A server response may also be explicitly verbatim. The network adapter must say so rather than feeding every response through a localizable-string initializer.

## Units and formatting

The app is already a good stress test for the later unit-aware UI effort.

`UnitValue` now provides the shared typed/Codable value and conversion model; Character still temporarily formats it by concatenating a formatted numeric value with `unit.abbreviation`. The unit types provide hand-written abbreviations such as `ft`, `lb`, `tsp`, `fl oz`, etc.

The localization design must support:

- locale-aware numeric formatting;
- unit-system/domain choice independent of locale where appropriate;
- localized/domain-standard unit abbreviations;
- spacing/order differences between value and unit;
- fractions used by the app's imperial presentation;
- D&D-specific units such as rounds that do not map neatly to Foundation measurements.

Do not solve this by converting everything to `Measurement` or by assuming the user's locale determines the document's unit system. The future unit-aware editor/presenter should sit on top of the shared typed formatting/text context.

## Composition helpers need review

Current helpers such as `presentationList`, `presentationNotes`, and `bulleted(...)` flatten values into English-oriented strings.

During migration, classify separators:

- visual separators/bullets can remain layout composition when language-neutral;
- grammatical lists should use locale-aware list formatting or localized templates;
- composed phrases must permit word reordering and punctuation changes by locale.

Do not implement document terminology as substring replacement inside these final strings.

## Application metadata (`AppInfo`)

The shared `AppInfo` accessors also belong in the localization/presentation migration inventory. `companyName` is user-facing vendor text and should be localizable. `supportEmail` and `supportURL` are verbatim contact data; version/build identifiers are verbatim technical metadata; the application icon belongs to image presentation.

Bundle-derived `displayName` is user-facing, but the bundle value remains authoritative. The current `"Unknown App"` / `"Unknown"` sentinel replacements should be removed from `AppInfo`: missing `displayName`, `version`, `build`, `fullVersion`, or `bundleIdentifier` should remain `nil`, with any localized fallback chosen by the consuming UI rather than injected by the metadata accessor.

## Property information and editor vocabulary

`SBJPropertyInfo` is already the right association point for property help and accessibility semantics. When Structure migrates its fields to the shared text resource, Character's existing `propertyInfo(for:)` implementations should become localizable without introducing a second metadata table.

This is preferable to attaching separate localization records to each property.

Generated property labels and enum choices also need a localization path. Their current un-camel-cased names are useful fallbacks, but the app must not surface untranslated Swift spelling in a localized build.

The maintenance rule in `Character/Documentation/PropertyInformation.md` remains: model changes should add coherent editor/presentation information at the same time. Localization becomes part of that same review rather than a later sweep.

## CharacterSheet and PDF fitting

CharacterSheet currently selects `StringPresentable.description`, `.abbreviation`, or `.multiLineDescription` before passing a `String` to `JCSText`.

That is too early. It prevents SBJLayout from choosing the best candidate for the actual font and bounds and makes the selected wording insensitive to locale-specific length.

The target flow is:

```text
Character/domain value
    -> shared text presentation/resource
    -> locale/vendor/document resolution
    -> ordered localized candidates
    -> JCSText measures actual candidates
    -> best fitting valid candidate is drawn
```

This is particularly important for dense sections such as Core Stats, Skills, Attacks, Health, spellcasting, and tables.

The PDF renderer must not change the model or permanently record which candidate happened to fit a particular layout.

## Document terminology

The old SBJLayout `Jargon` experiment should not be restored to the document model.

Document/settings-driven terminology belongs in an app-owned provider plugged into the shared SBJFoundation resolver. It should be sparse and inherit normal vocabulary for keys it does not override.

Examples could eventually include edition-specific or campaign-specific terms. The provider selects another unresolved/localizable resource; it should not replace substrings in already-localized output.

## Vendor/repackaging

A vendor repackage should similarly provide sparse resource overrides. The app should not fork or duplicate the full localization catalog for a handful of names.

Vendor identity/configuration is application policy. SBJFoundation should provide the resolver/provider contract, not know specific vendors.

An override must still be localizable in every supported locale and should participate in the same fit candidates as base copy.

## Server wording

Network models must explicitly preserve the semantic category of server text.

At least two cases exist:

1. **semantic/server vocabulary** — server identifies wording/meaning, but the app still applies localization, vendor/document terminology rules, formatting, accessibility, and fit selection;
2. **literal/verbatim content** — server owns the exact text and the app must not translate it.

The server should not send preformatted numbers/dates/currencies when the client is expected to respect client locale or document formatting. Prefer semantic values plus typed arguments.

When the server team declares required wording, the client contract must still account for the app's localization, vendor, terminology, accessibility, and layout requirements. If exact literal wording is genuinely required, model that fact explicitly rather than treating all server strings as literal by accident.

## Accessibility

Visible character-sheet/UI abbreviations are not automatically appropriate VoiceOver labels.

Examples such as `STR`, compact skill markers, or shortened section labels may need full spoken resources. `SBJPropertyInfo`/`Accessible` should carry independent localizable label/hint/value resources, with sensible fallback to the standard presentation where appropriate.

User-authored values remain verbatim when spoken, while surrounding labels/instructions remain localized.

## Search implications

Editor search should match the localized labels/options the user sees. It may also need to continue matching raw/model values for technical content.

When generated field labels and enum presentations migrate to shared resources, review `SearchProtocol`/editor search so localized vocabulary is searchable without requiring rendering.

## Finalization audit status

The pre-localization audits are complete. Their durable findings and exhaustive migration inventories are consolidated below in this document; the separate audit files have been removed. Current `String`/`StringPresentable` call sites remain intentionally unchanged until the shared SBJFoundation resource API is implemented.

## Migration strategy

### Phase 1: implement the proven SBJFoundation text-resource shape

Use an initializer whose argument is `LocalizedStringResource`, preserving `SBJTextResource("Armor Class")` source ergonomics while keeping the literal typed as Apple's localization resource. Keep explicit `verbatim` construction, standard/compact/abbreviated candidates, typed interpolation, and host-configured context/provider resolution. A final Xcode build fixture should mechanically confirm catalog extraction before broad migration.

### Phase 2: property/accessibility metadata

Migrate `SBJPropertyInfo`, `Accessible`, generated property labels, and editor-owned vocabulary. This proves that the shared representation works in SwiftUI without involving PDF fitting yet.

### Phase 3: Layout bridge

Add shared-resource support to `JCSText` and solve measurement/render candidate persistence. Keep current String initializers during migration.

### Phase 4: classify and replace `StringPresentable`

Migrate domain conformances by category rather than file-by-file blind replacement. Start with simple vocabulary enums and explicit abbreviations, then move into composed values and units.

A likely replacement is a Structure-defined presentation protocol whose value is the shared text resource/presentation, but its name/API should be chosen only after the resource type is stable.

### Phase 5: terminology/vendor/server providers

Add these once resource identity, locale resolution, and candidate selection are proven. This avoids building policy on top of unstable string identity.

### Phase 6: unit presentation integration

The semantic/Codable `UnitValue` model, common physical units, generic editor control, SBJStructure editor support, and PageLayout adoption are now in place. The remaining localization work is presentation: localized unit names/abbreviations, locale-aware numeric/fraction formatting, compound-unit presentation, and integration with the shared text/format context rather than a parallel formatting system.

## Migration audit targets

When implementation begins, explicitly audit:

- all `StringPresentable` conformances;
- CharacterSheet uses of `.description`, `.abbreviation`, and `.multiLineDescription`;
- manual interpolation of labels plus domain values;
- `presentationList`, `presentationNotes`, and `bulleted` helpers;
- `UnitValue` presentation and unit abbreviations;
- `SBJPropertyInfo` text;
- enum/property-name fallbacks;
- alert/error text crossing into `PendingAlert`;
- server/network models that contain display strings;
- user-authored fields that must be marked verbatim.

## Testing matrix

The app should eventually exercise the combined system across:

- at least one locale with substantially longer labels than English;
- right-to-left layout;
- vendor override + locale;
- document terminology override + locale;
- compact PDF fitting with a custom font;
- full visual text versus abbreviated visual text with full accessibility label;
- unit formatting in metric/imperial choices independent of locale;
- server semantic text versus server literal text;
- user-authored names/notes preserved exactly.

## Non-goals

- Do not localize persisted model/storage identifiers.
- Do not make CharacterSheet own localization lookup.
- Do not move `StringPresentable` wholesale into SBJLayout.
- Do not reintroduce document `Jargon` before the shared resolver exists.
- Do not assume locale, unit system, D&D rules edition, vendor, and document terminology are the same axis.

# Consolidated migration inventories

The following sections preserve the useful audit detail in the authoritative localization design rather than as separate historical documents. They are implementation inventories and may be deleted section-by-section as the listed seams disappear.

## UI-facing string migration inventory

### Status

This is the pre-localization step 3 inventory. No provisional localization wrapper is introduced here. The goal is to identify where runtime `String` currently means presentation, where it means verbatim/domain data, and where it is merely an identifier or debug representation.

### Direct SwiftUI literals

The app target currently has **60 direct string-literal SwiftUI presentation call sites** in the audited constructors/modifiers. Character and CharacterSheet have no direct occurrences of those SwiftUI literal constructors; their much larger presentation-string surface is primarily model metadata and `StringPresentable`/PDF composition.

Breakdown: `Button` 14, `Label` 21, `Picker` 1, `Text` 7, `TextField` 2, `Toggle` 2, `accessibilityLabel` 8, `alert` 5.

These literals are overwhelmingly **app-owned localizable UI vocabulary**. They should eventually use the shared SBJFoundation presentation-resource path, while retaining Apple String Catalog extraction ergonomics.

#### Interpolated templates require typed/verbatim arguments

The alert/empty-state strings containing character names, imported document names, dates, and counts are not wholly verbatim and not wholly localizable. The surrounding sentence is app-owned/localizable; character/document names remain verbatim; dates/counts remain typed until locale formatting. This is a core requirement for the resource API.

#### Accessibility is a separate resource channel

The direct `.accessibilityLabel(...)` strings are localizable app vocabulary. They should migrate with visible resources but must remain capable of differing from compact visual labels or symbols.

### Direct call-site inventory

| Kind | Source | Current expression |
| --- | --- | --- |
| accessibilityLabel | `Jove's Characters/view/CharacterEditorView.swift:45` | `.accessibilityLabel("Choose portrait")` |
| Label | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:38` | `Label("Unable to Generate PDF", image: .system("exclamationmark.triangle"))` |
| alert | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:105` | `.alert("Duplicate Character", isPresented: $isNamingDuplicate) {` |
| TextField | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:106` | `TextField("Name", text: $duplicateName)` |
| Button | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:107` | `Button("Cancel", role: .cancel) { }` |
| Button | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:108` | `Button("Duplicate") {` |
| Text | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:120` | `Text("Create an editable user document from \(repository.current?.character.person.identity.name ?? "the selected character").")` |
| alert | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:122` | `.alert("Delete Character?", isPresented: $isConfirmingDelete) {` |
| Button | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:123` | `Button("Cancel", role: .cancel) { }` |
| Button | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:124` | `Button("Delete", role: .destructive) {` |
| Text | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:134` | `Text("Delete \(repository.current?.character.person.identity.name ?? "this character")? This cannot be undone.")` |
| alert | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:136` | `.alert("Character Already Exists", isPresented: Binding(` |
| Button | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:140` | `Button("Cancel", role: .cancel) { repository.cancelImportConflict() }` |
| Button | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:141` | `Button("Import as Copy") { resolveImportConflict(.importAsCopy) }` |
| Button | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:142` | `Button("Replace Existing", role: .destructive) { resolveImportConflict(.replaceExisting) }` |
| Text | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:145` | `Text("The imported document ‘\(conflict.incomingName)’ (modified \(conflict.incomingModifiedAt.formatted(date: .abbreviated, time: .shortened))) has the same document ID as ‘\(conflict.existingName)’ (modified \(conflict.existingModifiedAt.formatted(date: .abbreviated, time: .shortened))). Replace the existing document, or import this file as a new copy?")` |
| alert | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:173` | `.alert(` |
| Button | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:180` | `Button("OK", role: .cancel) { characterFileErrorMessage = nil }` |
| Label | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:248` | `Label("No Characters", image: .system("person.crop.circle.badge.plus"))` |
| Text | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:250` | `Text("Create a character or import a character file to get started.")` |
| Button | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:252` | `Button("New Character", action: createCharacter)` |
| Button | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:253` | `Button("Import Character") { isImportingCharacter = true }` |
| Label | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:257` | `Label("No Character Selected", image: .system("person.crop.circle"))` |
| Text | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:259` | `Text("Choose a character from the Characters menu, or import a character file.")` |
| Button | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetPDFView.swift:261` | `Button("Import Character") { isImportingCharacter = true }` |
| Label | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetToolbar.swift:84` | `Button(action: onEditCharacter) { Label("Edit", image: .system("rectangle.and.pencil.and.ellipsis")) }` |
| Label | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetToolbar.swift:85` | `Button(action: onEditSections) { Label("Sections", image: .system("rectangle.grid.1x3")) }` |
| Label | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetToolbar.swift:86` | `Button(action: onEditTheme) { Label("Theme", image: .system("paintpalette")) }` |
| Label | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetToolbar.swift:87` | `Button(action: onEditPageLayout) { Label("Page Layout", image: .system("inset.filled.rectangle.portrait")) }` |
| Label | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetToolbar.swift:95` | `Button(action: { onTemplate(true) }) { Label("Make Template", image: .system("lock")) }` |
| Label | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetToolbar.swift:97` | `Button(role: .destructive, action: onDelete) { Label("Delete", image: .system("trash")) }` |
| Label | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetToolbar.swift:99` | `Button(action: { onTemplate(false) }) { Label("Unlock", image: .system("lock.open")) }` |
| Label | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetToolbar.swift:106` | `Button(action: onDuplicate) { Label("Duplicate", image: .system("plus.square.on.square")) }` |
| Label | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetToolbar.swift:113` | `Button(action: onCreate) { Label("New Character", image: .system("person.badge.plus")) }` |
| Label | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetToolbar.swift:136` | `Label("Characters", image: .system("person.2"))` |
| Label | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetToolbar.swift:160` | `Label("Share PDF", image: .system("square.and.arrow.up"))` |
| Label | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetToolbar.swift:164` | `Label("Export Character", image: .system("shippingbox"))` |
| Label | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetToolbar.swift:168` | `Label("Import Character", image: .system("square.and.arrow.down"))` |
| Label | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetToolbar.swift:177` | `Label("Export Swift Source", image: .system("swift"))` |
| Label | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetToolbar.swift:182` | `Label("Character File", image: .system("doc.badge.gearshape"))` |
| Label | `Jove's Characters/view/CharacterSheetPDFView/CharacterSheetToolbar.swift:188` | `Label("Import File", image: .system("square.and.arrow.down"))` |
| Text | `Jove's Characters/view/SectionEditorView.swift:41` | `Text("Sections (\(rows.count))")` |
| accessibilityLabel | `Jove's Characters/view/SectionEditorView.swift:52` | `.accessibilityLabel("Go to first section")` |
| accessibilityLabel | `Jove's Characters/view/SectionEditorView.swift:61` | `.accessibilityLabel("Go to last section")` |
| accessibilityLabel | `Jove's Characters/view/SectionEditorView.swift:94` | `.accessibilityLabel("Add section")` |
| Text | `Jove's Characters/view/SectionEditorView.swift:148` | `Text("\((index ?? 0) + 1). \(row.section.id)")` |
| accessibilityLabel | `Jove's Characters/view/SectionEditorView.swift:155` | `.accessibilityLabel("No rendered location to auto-scroll to")` |
| accessibilityLabel | `Jove's Characters/view/SectionEditorView.swift:165` | `.accessibilityLabel("Move section up")` |
| accessibilityLabel | `Jove's Characters/view/SectionEditorView.swift:173` | `.accessibilityLabel("Move section down")` |
| accessibilityLabel | `Jove's Characters/view/SectionEditorView.swift:181` | `.accessibilityLabel("Delete section")` |
| TextField | `Jove's Characters/view/SectionEditorView.swift:185` | `TextField("Display Name", text: sectionBinding(for: rowID, fallback: row.section).displayName)` |
| Picker | `Jove's Characters/view/SectionEditorView.swift:201` | `Picker("Pagination", selection: pageBreakBinding(for: rowID, fallback: row.section, isFirst: index == rows.startIndex)) {` |
| Toggle | `Jove's Characters/view/SectionEditorView.swift:207` | `Toggle("End Row", isOn: sectionBinding(for: rowID, fallback: row.section).fill)` |
| Toggle | `Jove's Characters/view/SectionEditorView.swift:208` | `Toggle("Always Show", isOn: sectionBinding(for: rowID, fallback: row.section).alwaysShow)` |
| Label | `Jove's Characters/view/EditorPresentation/EditorHost.swift:88` | `Label("No Character Selected", image: .system("person.crop.circle"))` |
| alert | `Jove's Characters/view/EditorPresentation/EditorHost.swift:132` | `.alert(` |
| Button | `Jove's Characters/view/EditorPresentation/EditorHost.swift:139` | `Button("OK", role: .cancel) { saveErrorMessage = nil }` |
| Button | `Jove's Characters/view/EditorPresentation/EditorHost.swift:154` | `Button("Restore") {` |
| Button | `Jove's Characters/view/EditorPresentation/EditorHost.swift:160` | `Button("Done") { dismiss() }` |

### SBJStructure property/help metadata

Character currently contains **540 literal `summary`/`details`/accessibility argument occurrences across 40 files** in its structured-editor/property-information layer. These strings are framework/app-owned explanatory copy and should become localizable resources when `SBJPropertyInfo` migrates. They must not be treated as model data.

The largest concentrations are:

- `StringPresentable/combat/Attack+StringPresentable.swift` — 92 literal metadata arguments
- `StringPresentable/combat/DefensiveEquipment+StringPresentable.swift` — 46 literal metadata arguments
- `StringPresentable/capabilities/Spellcasting+StringPresentable.swift` — 42 literal metadata arguments
- `StringPresentable/person/AssociatedCreature+StringPresentable.swift` — 22 literal metadata arguments
- `StringPresentable/Character+StringPresentable.swift` — 16 literal metadata arguments
- `StringPresentable/life/HealthCounter+StringPresentable.swift` — 16 literal metadata arguments
- `StringPresentable/life/MovementAndSenses+StringPresentable.swift` — 16 literal metadata arguments
- `StringPresentable/person/Identity+StringPresentable.swift` — 16 literal metadata arguments
- `StringPresentable/possessions/Equipment+StringPresentable.swift` — 16 literal metadata arguments
- `StringPresentable/Advancement+StringPresentable.swift` — 14 literal metadata arguments
- `StringPresentable/capabilities/Proficiencies+StringPresentable.swift` — 14 literal metadata arguments
- `StringPresentable/person/Appearance+StringPresentable.swift` — 14 literal metadata arguments
- `StringPresentable/person/Person+StringPresentable.swift` — 14 literal metadata arguments
- `StringPresentable/possessions/Valuable+StringPresentable.swift` — 14 literal metadata arguments
- `StringPresentable/capabilities/AttackAttempt+StringPresentable.swift` — 12 literal metadata arguments

### String intent categories found

#### 1. Localizable app/framework vocabulary

Button titles, menu labels, editor field labels, empty-state copy, alert titles, validation/help text, enum/domain vocabulary, and accessibility instructions. These should eventually enter the shared unresolved presentation-resource system.

#### 2. Verbatim user/document content

Character names, player-entered names/notes/descriptions, imported document names, custom section titles, campaign text, and similar persisted content. These must remain explicitly verbatim even when embedded in localized templates.

#### 3. Stable identifiers and serialization keys

Document IDs, `SheetSection.id`, defaults keys, source/property names, schema names, file extensions, Swift source expressions, and enum raw values used for persistence are not localization targets. Some types also have a separate `displayName`; the two roles must not be collapsed.

#### 4. Typed/formatted values

Dates, numbers, dice, unit values, money, bonuses, page dimensions, and other domain values must remain typed until formatting. `StringPresentable` currently flattens many of these too early.

#### 5. Debug/error diagnostics

Debug descriptions, validation paths/type names, source-generation strings, and technical diagnostics should remain ordinary strings unless they are deliberately surfaced to end users. User-facing error *presentation* should wrap/translate the diagnostic rather than make every diagnostic localizable.

### Public/raw String seams to migrate first

The audit identifies several especially important boundaries for the localization implementation:

- `SBJPropertyInfo` titles/summaries/details/accessibility text;
- generated SBJStructure property and enum display names;
- `Accessible`/`AccessibleItem` visible and spoken strings;
- `SBJCompactMenuLabel.text` and other reusable UIVocabulary labels;
- unit `displayName`/abbreviation presentation;
- `SheetSection.displayName` and other document-vocabulary fields where the app must decide localizable semantic name versus explicit document override;
- alerts and error presentation, especially interpolated templates;
- CharacterSheet `StringPresentable` consumption.

### What is intentionally not changed in this pass

- No UI literal is wrapped in a temporary localization type.
- `StringPresentable` is not renamed or moved.
- User-authored strings are not heuristically localized.
- Persisted identifiers/raw values are not changed.
- Localized candidate selection/retry is not changed until the shared candidate/resource API exists. Existing geometric minimum-content/fill measurement is independent of that future selection layer.

### Next design implication

The localization API must make the **localizable vs verbatim vs typed/formatted** choice at construction time and preserve that choice through composition. A final runtime `String` is too late to make that decision reliably.

## Legacy `StringPresentable` migration inventory

### Status

This is the pre-localization step 4 inventory. It deliberately does **not** replace `StringPresentable` yet. Its purpose is to record what the existing protocol is actually doing so the shared presentation-resource design is driven by real call sites rather than by a hypothetical string wrapper.

The dedicated `StringPresentable` tree currently contains **101 domain conformances**. A single conformance may serve more than one presentation role; the classifications below identify migration concerns rather than mutually exclusive type categories.

### Key findings

- `StringPresentable` is not one abstraction. It currently combines localizable vocabulary, compact abbreviations, composed domain formatting, verbatim/user content, and PDF-fit candidates.
- The `RawRepresentable<String>` default (`rawValue.uncamelCased`) is a useful English development fallback, but cannot be the localized presentation identity.
- The default `multiLineDescription` mechanically replaces spaces with line breaks. That is layout behavior, **not** a distinct localization candidate, and should disappear when SBJLayout receives unresolved presentation candidates.
- Only explicit alternate wording should become a separate compact/abbreviated/multiline resource. Ordinary wrapping and line breaking belong to the renderer.
- Unit conformances are now transitional. `UnitValue` and the common physical-unit types live in SBJFoundation; their visible names/abbreviations must ultimately be resolved by the shared unit/presentation system rather than Character-owned strings.
- Many composed values include both app-owned grammar and verbatim values (names, notes, source text). The future representation must keep those parts typed/separate until resolution instead of localizing a final interpolated string.

### Migration buckets

#### Localizable vocabulary

Enum-like values such as abilities, damage types, conditions, movement modes, rules choices, and other finite domain terms should resolve from semantic identity to localizable presentation resources. Raw enum values remain persistence/program identity, not UI copy.

#### Compact candidates

Existing `abbreviation` overrides prove that some concepts need a separately authored compact candidate. These must be independently localizable; they must not be generated mechanically from the localized full name.

#### Composed/formatted values

Attacks, defenses, health, spellcasting, dice, rules summaries, movement, money, and similar values build phrases from typed values. They should migrate to structured/interpolated resources or domain presentation objects, not final-string localization.

#### Verbatim/domain content

Names, notes, custom descriptions, item/spell/feature names, and similar character/document content must remain verbatim while surrounding grammar remains localizable.

#### Layout alternatives

`multiLineDescription` is overwhelmingly a legacy layout mechanism. The future SBJLayout fitting API should receive ordered semantic candidates and perform wrapping itself. The explicit `Attack.Effect` override currently returns the same text and therefore does not demonstrate a genuinely separate translated multiline resource.

### Conformance inventory

| Type | Current migration concerns | Source |
| --- | --- | --- |
| `Ability` | localizable vocabulary, compact candidate | `StringPresentable/life/AbilityScore+StringPresentable.swift` |
| `AbilityScore` | composed/formatted | `StringPresentable/life/AbilityScore+StringPresentable.swift` |
| `Advancement` | composed/formatted | `StringPresentable/Advancement+StringPresentable.swift` |
| `AdvancementMethod` | localizable vocabulary | `StringPresentable/Advancement+StringPresentable.swift` |
| `AlignmentAxis` | localizable vocabulary, compact candidate | `StringPresentable/person/CharacterAlignment+StringPresentable.swift` |
| `Armor` | composed/formatted | `StringPresentable/combat/DefensiveEquipment+StringPresentable.swift` |
| `ArmorCategory` | localizable vocabulary | `StringPresentable/combat/DefensiveEquipment+StringPresentable.swift` |
| `ArmorDexterityRule` | localizable vocabulary | `StringPresentable/combat/DefensiveEquipment+StringPresentable.swift` |
| `AssociatedCreature` | composed/formatted, contains verbatim/domain data | `StringPresentable/person/AssociatedCreature+StringPresentable.swift` |
| `AssociatedCreatureKind` | localizable vocabulary | `StringPresentable/person/AssociatedCreature+StringPresentable.swift` |
| `AssociatedStatBlock` | contains verbatim/domain data | `StringPresentable/person/AssociatedCreature+StringPresentable.swift` |
| `Attack` | contains verbatim/domain data | `StringPresentable/combat/Attack+StringPresentable.swift` |
| `Attack.Area` | composed/formatted | `StringPresentable/combat/Attack+StringPresentable.swift` |
| `Attack.Area.Shape` | localizable vocabulary | `StringPresentable/combat/Attack+StringPresentable.swift` |
| `Attack.Condition` | localizable vocabulary | `StringPresentable/combat/Attack+StringPresentable.swift` |
| `Attack.Damage` | composed/formatted | `StringPresentable/combat/Attack+StringPresentable.swift` |
| `Attack.DamageType` | localizable vocabulary | `StringPresentable/combat/Attack+StringPresentable.swift` |
| `Attack.Delivery` | localizable vocabulary | `StringPresentable/combat/Attack+StringPresentable.swift` |
| `Attack.Duration` | composed/formatted | `StringPresentable/combat/Attack+StringPresentable.swift` |
| `Attack.Effect` | composed/formatted, compact candidate, explicit multiline override | `StringPresentable/combat/Attack+StringPresentable.swift` |
| `Attack.Property` | localizable vocabulary | `StringPresentable/combat/Attack+StringPresentable.swift` |
| `Attack.Range` | composed/formatted | `StringPresentable/combat/Attack+StringPresentable.swift` |
| `Attack.Range.Kind` | localizable vocabulary | `StringPresentable/combat/Attack+StringPresentable.swift` |
| `Attack.SaveResult` | localizable vocabulary | `StringPresentable/combat/Attack+StringPresentable.swift` |
| `Attack.SaveTiming` | localizable vocabulary | `StringPresentable/combat/Attack+StringPresentable.swift` |
| `Attack.SavingThrow` | composed/formatted | `StringPresentable/combat/Attack+StringPresentable.swift` |
| `Attack.Source` | localizable vocabulary | `StringPresentable/combat/Attack+StringPresentable.swift` |
| `Attack.Target` | composed/formatted | `StringPresentable/combat/Attack+StringPresentable.swift` |
| `Attack.Target.Kind` | localizable vocabulary | `StringPresentable/combat/Attack+StringPresentable.swift` |
| `Attack.Timing` | localizable vocabulary | `StringPresentable/combat/Attack+StringPresentable.swift` |
| `Attack.Trigger` | localizable vocabulary | `StringPresentable/combat/Attack+StringPresentable.swift` |
| `Attack.Weapon` | composed/formatted | `StringPresentable/combat/Attack+StringPresentable.swift` |
| `AttackAttempt.Cover` | localizable vocabulary | `StringPresentable/capabilities/AttackAttempt+StringPresentable.swift` |
| `AttackAttempt.Outcome` | localizable vocabulary | `StringPresentable/capabilities/AttackAttempt+StringPresentable.swift` |
| `AttackAttempt.RollMode` | localizable vocabulary | `StringPresentable/capabilities/AttackAttempt+StringPresentable.swift` |
| `AttackBonusRule` | localizable vocabulary, composed/formatted | `StringPresentable/types/DerivedValueRules+StringPresentable.swift` |
| `AttunementState` | localizable vocabulary, compact candidate | `StringPresentable/possessions/PhysicalPossession+StringPresentable.swift` |
| `BioSex` | localizable vocabulary, compact candidate | `StringPresentable/person/Orientation+StringPresentable.swift` |
| `Character` | composed/formatted | `StringPresentable/Character+StringPresentable.swift` |
| `CharacterAlignment` | composed/formatted, compact candidate | `StringPresentable/person/CharacterAlignment+StringPresentable.swift` |
| `CharacterSize` | localizable vocabulary | `StringPresentable/person/Identity+StringPresentable.swift` |
| `ClassLevel` | contains verbatim/domain data | `StringPresentable/person/Identity+StringPresentable.swift` |
| `CreatureType` | localizable vocabulary | `StringPresentable/person/Identity+StringPresentable.swift` |
| `Currency` | localizable vocabulary, compact candidate | `StringPresentable/possessions/Currency+StringPresentable.swift` |
| `DeathSaveResult` | localizable vocabulary | `StringPresentable/life/HealthCounter+StringPresentable.swift` |
| `Defenses` | composed/formatted | `StringPresentable/combat/Defenses+StringPresentable.swift` |
| `DefensiveEquipment` | composed/formatted | `StringPresentable/combat/DefensiveEquipment+StringPresentable.swift` |
| `DetailedSection` | contains verbatim/domain data | `StringPresentable/types/DetailedSection+StringPresentable.swift` |
| `Dice` | composed/formatted | `StringPresentable/types/Die+StringPresentable.swift` |
| `Die` | composed/formatted | `StringPresentable/types/Die+StringPresentable.swift` |
| `Encumbrance` | composed/formatted | `StringPresentable/possessions/Encumbrance+StringPresentable.swift` |
| `EncumbranceRule` | localizable vocabulary | `StringPresentable/possessions/Encumbrance+StringPresentable.swift` |
| `EncumbranceState` | localizable vocabulary | `StringPresentable/possessions/Encumbrance+StringPresentable.swift` |
| `Equipment` | contains verbatim/domain data | `StringPresentable/possessions/Equipment+StringPresentable.swift` |
| `Feature` | contains verbatim/domain data | `StringPresentable/capabilities/Feature+StringPresentable.swift` |
| `Gender` | localizable vocabulary, compact candidate | `StringPresentable/person/Orientation+StringPresentable.swift` |
| `HealthCounter` | composed/formatted | `StringPresentable/life/HealthCounter+StringPresentable.swift` |
| `Identity` | contains verbatim/domain data | `StringPresentable/person/Identity+StringPresentable.swift` |
| `KeyStatRule` | localizable vocabulary | `StringPresentable/life/KeyStat+StringPresentable.swift` |
| `KeyStatType` | localizable vocabulary, compact candidate | `StringPresentable/life/KeyStat+StringPresentable.swift` |
| `LengthUnit` | unit/typed formatting, compact candidate | `StringPresentable/types/Units+StringPresentable.swift` |
| `LifeState` | localizable vocabulary | `StringPresentable/life/HealthTracker+StringPresentable.swift` |
| `MagicTradition` | localizable vocabulary | `StringPresentable/capabilities/Spellcasting+StringPresentable.swift` |
| `MassUnit` | unit/typed formatting, compact candidate | `StringPresentable/types/Units+StringPresentable.swift` |
| `MeasurementSystem` | unit/typed formatting, localizable vocabulary | `StringPresentable/types/Units+StringPresentable.swift` |
| `Moneys` | composed/formatted, compact candidate | `StringPresentable/possessions/Moneys+StringPresentable.swift` |
| `MoralityAxis` | localizable vocabulary, compact candidate | `StringPresentable/person/CharacterAlignment+StringPresentable.swift` |
| `MovementAndSenses` | composed/formatted | `StringPresentable/life/MovementAndSenses+StringPresentable.swift` |
| `MovementMode` | localizable vocabulary | `StringPresentable/life/MovementAndSenses+StringPresentable.swift` |
| `MovementSpeed` | composed/formatted | `StringPresentable/life/MovementAndSenses+StringPresentable.swift` |
| `Orientation` | localizable vocabulary, compact candidate | `StringPresentable/person/Orientation+StringPresentable.swift` |
| `Personality` | contains verbatim/domain data | `StringPresentable/person/Personality+StringPresentable.swift` |
| `PossessionLocation` | localizable vocabulary | `StringPresentable/possessions/PhysicalPossession+StringPresentable.swift` |
| `Proficiencies` | composed/formatted | `StringPresentable/capabilities/Proficiencies+StringPresentable.swift` |
| `Proficiency` | localizable vocabulary | `StringPresentable/capabilities/Proficiencies+StringPresentable.swift` |
| `Pronouns` | composed/formatted, compact candidate | `StringPresentable/person/Orientation+StringPresentable.swift` |
| `Recharge` | localizable vocabulary | `StringPresentable/types/ResourceCounter+StringPresentable.swift` |
| `Relationship` | contains verbatim/domain data | `StringPresentable/person/Relationship+StringPresentable.swift` |
| `ResourceCounter` | composed/formatted | `StringPresentable/types/ResourceCounter+StringPresentable.swift` |
| `ReusableResource` | composed/formatted | `StringPresentable/capabilities/ReusableResource+StringPresentable.swift` |
| `Roll` | composed/formatted | `StringPresentable/types/Die+StringPresentable.swift` |
| `RulesProfile` | localizable vocabulary | `StringPresentable/Character+StringPresentable.swift` |
| `SaveDCRule` | localizable vocabulary, composed/formatted | `StringPresentable/types/DerivedValueRules+StringPresentable.swift` |
| `SenseKind` | localizable vocabulary | `StringPresentable/life/MovementAndSenses+StringPresentable.swift` |
| `Shield` | composed/formatted | `StringPresentable/combat/DefensiveEquipment+StringPresentable.swift` |
| `Skill` | localizable vocabulary | `StringPresentable/capabilities/SkillScore+StringPresentable.swift` |
| `SkillMark` | localizable vocabulary, compact candidate | `StringPresentable/capabilities/SkillScore+StringPresentable.swift` |
| `SpecialSense` | composed/formatted | `StringPresentable/life/MovementAndSenses+StringPresentable.swift` |
| `Spell` | contains verbatim/domain data | `StringPresentable/capabilities/Spellcasting+StringPresentable.swift` |
| `Spellcasting` | composed/formatted | `StringPresentable/capabilities/Spellcasting+StringPresentable.swift` |
| `SpellcastingRule` | localizable vocabulary, composed/formatted | `StringPresentable/types/DerivedValueRules+StringPresentable.swift` |
| `SpellLevel` | localizable vocabulary, compact candidate | `StringPresentable/capabilities/Spellcasting+StringPresentable.swift` |
| `SpellPreparation` | localizable vocabulary | `StringPresentable/capabilities/Spellcasting+StringPresentable.swift` |
| `SpellSlotCounter` | composed/formatted | `StringPresentable/capabilities/Spellcasting+StringPresentable.swift` |
| `TimeUnit` | unit/typed formatting, compact candidate | `StringPresentable/types/Units+StringPresentable.swift` |
| `UnarmoredDefenseRule` | composed/formatted | `StringPresentable/combat/DefensiveEquipment+StringPresentable.swift` |
| `UnitCategory` | unit/typed formatting, localizable vocabulary | `StringPresentable/types/Units+StringPresentable.swift` |
| `UnitValue` | unit/typed formatting | `StringPresentable/types/Units+StringPresentable.swift` |
| `Valuable` | contains verbatim/domain data | `StringPresentable/possessions/Valuable+StringPresentable.swift` |
| `Valuables` | composed/formatted | `StringPresentable/possessions/Valuables+StringPresentable.swift` |
| `VolumeUnit` | unit/typed formatting, compact candidate | `StringPresentable/types/Units+StringPresentable.swift` |

### CharacterSheet consumers

The current PDF path consumes `description`, `abbreviation`, and `multiLineDescription` before or while constructing `JCSText`. These call sites are migration targets because candidate selection ultimately belongs after locale/terminology resolution and at the point where SBJLayout knows the actual geometry and font.

The new minimum-content measurement path strengthens that requirement: each localized candidate can have both a preferred width and a minimum viable width under its break policy. A longer translation may still fit by wrapping even when its preferred width grows, while another candidate may require a compact/abbreviated retry because its minimum width exceeds the allocated geometry. Candidate choice therefore must remain available until Layout performs measurement.

Known high-value consumers include Core Stats, Health, Attacks, table helpers, and `Themed` text construction. The localization implementation should migrate these after the shared resource API is proven, rather than changing them during this audit.

### Acceptance criteria for retiring StringPresentable

`StringPresentable` can be removed only when the replacement can represent all of the following without flattening intent:

- app-owned localizable standard wording;
- independently authored compact/abbreviated candidates;
- verbatim/user-authored values embedded in localized grammar;
- typed number/date/unit/dice/domain formatting;
- accessibility wording distinct from the fitted visible candidate;
- renderer-selected fit candidates without model mutation;
- document/vendor/rules terminology overrides before final localization.

## Cross-package final audit findings

This completes the audits after the separate UI-string and `StringPresentable` inventories.

### Formatting and locale

Active app/domain formatting hotspots are small but important:

- Import-conflict UI formats modification dates directly with Swift `FormatStyle`; this is localizable UI presentation and should resolve with the effective presentation locale.
- `Units+StringPresentable` creates a `NumberFormatter`; this is legacy presentation composition and should disappear when unit values use the shared presentation-resource formatter.
- D&D/domain formatting embedded in `description`/`abbreviation` remains classified in the legacy `StringPresentable` migration inventory below; do not migrate it piecemeal.

### Images and colors

Active SwiftUI code is already routed through SBJFoundation `ImageReference`/semantic appearance vocabulary. The `UIColor.systemBlue` occurrence is test rendering data, not application chrome.

### Alerts, validation and accessibility

The app has several multi-action alerts whose semantics exceed current `PendingAlert`; they should be localization clients, not forced into `PendingAlert` before that API is redesigned. Domain property/help/accessibility metadata is the largest localizable surface and is already inventoried.

### Public API

`Character` and `CharacterSheet` expose large domain APIs by design. Localization should avoid changing persistence identities/raw enum values merely to obtain localized display strings. Stable model identity and presentation vocabulary must stay separate.

### Dependency/platform boundary

Character depends on SBJFoundation; CharacterSheet depends on Character, SBJFoundation and SBJLayout.

Platform-specific app code is concentrated in thumbnails, workspace presentation policy, and PDF document orchestration. Package-document lifecycle differences are contained by SBJFoundation. Raw PDF viewer identity remains contained by SBJLayout.

### Dead/duplicate code

No active duplicate PageLayout implementation was found: the app view is only an `EditorHost`/persistence adapter. No additional code should be moved solely for localization.

### Test gaps

The current Character/CharacterSheet/app suites already provide model, built-in-document and PDF coverage. Before localization, add no broad snapshot suite. Future resource work needs focused tests for domain vocabulary resolution, alternate candidates, verbatim preservation, and unit formatting.
