# Localization and Presentation Resource Design

### Noun-based semantic action buttons

`SBJAddButton(_:)` and `SBJDeleteButton(_:)` intentionally preserve noun-based API for the current pre-localization UI. Their English phrases such as `Add <noun>`, `Delete <noun>`, and the delete confirmation sentence are **not** a precedent for translating the verb and noun independently. The localization migration must represent each complete grammatical action/confirmation as a text resource so languages can reorder words and apply case, gender, number, or other inflection. `SBJDismissButton` is framework-owned vocabulary and belongs in the same resource/catalog migration.


## Status

This document is the current design direction after the Structure/editor/UIVocabulary consolidation and the review of SBJLayout and Jove's Characters. It replaces the earlier collapse inventory as the working localization design.

No shared localization API described here is implemented yet. Names are provisional where called out.

## Problem statement

The required system is broader than ordinary language lookup and broader than text. A human-facing concept may vary because of:

1. locale, language, grammar, number/date/unit formatting, writing direction, and cultural convention;
2. available space, selected font, line count, abbreviation, explicit line breaks, or other fit constraints;
3. symbol/image choice, including SF Symbol versus bundled imagery, RTL behavior, cultural meaning, and vendor imagery;
4. semantic color, theme, contrast, differentiate-without-color, and other accessibility settings;
5. vendor/repackaging vocabulary and visual language;
6. document-, settings-, or domain-specific terminology and presentation;
7. server-owned wording/resources that may be either semantic/localizable input or deliberate verbatim content;
8. accessibility wording, which may need to remain descriptive even when visible copy or imagery is compact.

These concerns must not be flattened to `String`, raw SF Symbol names, or literal colors before the presentation layer has enough information to make the appropriate decision.

## Core design principles

### Source-string ergonomics are a requirement

Do not create or maintain an enum containing hundreds of copy keys.

The ordinary call site should preserve Apple's model: a source string is localizable unless the caller explicitly says otherwise. Conceptually:

```swift
SBJTextResource("Armor Class")
SBJTextResource(verbatim: userEnteredText)
```

`SBJTextResource` is a working name. `SBJText my be sufficient.

Before committing to the exact initializer/literal API, verify that it preserves Xcode String Catalog extraction. If a custom `ExpressibleByStringLiteral` wrapper prevents extraction, prefer an initializer whose parameter is `LocalizedStringResource` or another extraction-friendly shape rather than sacrificing catalog tooling for syntactic convenience.

### Preserve intent, not just output

The shared representation must distinguish at least:

- app/framework-owned localizable text;
- explicitly verbatim text, including user-authored values;
- system-owned text where SwiftUI/UIKit should provide localization;
- formatted/interpolated text whose values remain typed until formatting;
- alternate presentations of the same concept.

A runtime `String` is a terminal representation. Once text has been flattened to `String`, the framework can no longer reliably know whether it should localize, format, abbreviate, override, or preserve it verbatim.

### One concept may have several valid presentations

Localization is not a one-string lookup problem. A concept may have independently translated candidates such as:

```text
Maximum Hit Points
Max Hit Points
Max HP
```

The shared model should expose an ordered set of presentation candidates rather than requiring renderers to invent abbreviations mechanically.

Working candidate roles are:

- `standard` — preferred/full wording;
- `compact` — shorter wording that retains normal readability;
- `abbreviated` — domain abbreviation or highly compressed wording.

Explicit multiline wording may also be a candidate when the words actually differ. Merely inserting line breaks into the same words is primarily a layout policy and should not automatically become a separate localization resource.

Hyphenation, wrapping, truncation, and allowed line counts are renderer/layout concerns. The shared resource may carry hints or explicit author-approved break opportunities, but it should not measure fonts or geometry.

### Resolution and fitting are separate phases

The conceptual pipeline is:

```text
source text/resource
    -> semantic override selection
       (vendor/document/settings/server vocabulary)
    -> locale resolution + typed formatting
    -> ordered resolved candidates
    -> renderer-specific fitting
    -> visible output
```

Semantic override layers must operate on text identity/resources, not by replacing substrings in already-localized prose.

The host application should be able to configure sparse override providers. The framework should not hard-code one universal precedence order for vendor, document, and server vocabulary; different products may legitimately assign different authority. The configured resolver owns precedence.

### Formatting remains typed as long as possible

Dates, numbers, currencies, measurements, lists, and other values should use Foundation formatting or domain formatters with an explicit locale/context rather than server-preformatted strings or ad-hoc concatenation.

This does not mean every domain value can use a stock `FormatStyle`. D&D units, recipe measures, LEGO dimensions, and other application domains may need custom formatting. The architectural requirement is that the value and formatting intent survive until resolution instead of being flattened early.

### Accessibility is related copy, not the visible compact string

A compact visible label may be unsuitable as spoken text. For example, an abbreviation that is obvious on a character sheet may be ambiguous when spoken.

Accessibility label, hint, and value should use the same localizable/verbatim resource model, but they remain distinct semantic channels. A renderer may use the full/standard visible resource as an accessibility fallback, but it must not assume that the currently fitted visual candidate is the correct spoken candidate.

### Text, imagery, and color are sibling presentation resources

The architecture should not solve text first and then bolt imagery/color onto it as unrelated APIs. They share the same high-level questions: who owns the meaning, what is literal versus semantic, what context may override it, and what accessibility fallback is required.

The current code already provides useful seeds:

- `ImageReference` is the shared image-reference boundary for system symbols, bundled images, file URLs, and no image (`system`, `asset`, `resource`, `file`, `none`). SwiftUI and UIKit realize the same reference instead of maintaining separate image-name and image-source types.
- `AccessibleImage` / `AccessibleImageItem` associate imagery with spoken labeling/hint/value semantics.
- `ColorVariants` describes concrete ways to construct a color.
- `SBJUIAppearance` already names semantic editor/UI color roles and adapts some of them for contrast/accessibility.

These are not yet one generalized resource system, and they should not be mechanically merged. In particular, **source/candidate** and **semantic identity** are different jobs. `ImageReference.system("plus.circle")` identifies today's visual candidate; “add item” is the semantic action. `ColorVariants.asset("Accent")` identifies a color source; “invalid value” is the semantic role.

Framework controls should therefore avoid raw `Image(systemName:)` and raw meaning-bearing colors at call sites. They should enter through `ImageReference`/semantic image vocabulary and `SBJUIAppearance`/semantic color roles so a future resolver has a boundary to intercept. The SubjectEditor now follows this rule for button imagery. SwiftUI `Label` values backed by `ImageReference` use SwiftUI’s built-in label styles directly. Menu/container boundaries set `.labelStyle(.titleAndIcon)` explicitly so Mac Catalyst does not suppress menu-item symbols; individual labels should not repeat that style when it is already inherited.

### Presentation-resource decision tree

For every user-facing text, image/symbol, or color, classify it before deciding how it resolves:

1. **Is it persisted/user/domain data rather than presentation?**
   - Text entered by a user remains verbatim data.
   - A stored image/file/URL remains image data (`ImageReference` territory), not localized UI imagery.
   - A stored user/domain color remains a value (`CodableColor`), not a semantic UI role.
2. **Is the system the semantic owner?**
   - Prefer system-localized actions/controls where the platform already owns them.
   - A system SF Symbol may still be the default image candidate, but application code should preserve the semantic boundary if the symbol conveys app meaning.
3. **Is this app/framework-owned semantic presentation?**
   - Text -> localizable text resource plus optional compact/abbreviated candidates.
   - Image/symbol -> semantic image resource/role with one or more `ImageReference` candidates.
   - Color -> semantic color role resolved through appearance/theme context rather than a literal color at the use site.
4. **Does locale/culture/writing direction affect the presentation?**
   - Text may translate/reorder.
   - Symbols may need a different glyph, bundled image, mirroring policy, or no image at all.
   - Color usually does not “translate,” but cultural/domain meaning can vary and must not be assumed universal.
5. **Do vendor/document/server policies override it?**
   - Sparse providers should be able to replace text, image candidates, and semantic color/theme roles without forking the whole resource set.
6. **What accessibility companion/fallback is required?**
   - `AccessibleImageItem` is the current model to build from: visible image and spoken text are related but independent.
   - Meaning must never depend on color alone; `accessibilityDifferentiateWithoutColor` should expose shape/symbol/text alternatives where required.
   - High contrast, light/dark appearance, and reduced-transparency behavior belong in color/appearance resolution.
7. **What does the renderer choose?**
   - Text renderer chooses among resolved wording candidates based on geometry.
   - Image renderer chooses/resizes an already-resolved image candidate according to available presentation rules.
   - Color renderer receives a resolved semantic color; it should not infer meaning from arbitrary RGB values.

This decision tree is intentionally shared even if the eventual concrete types remain separate.

### Symbology and imagery

`ImageReference` should remain the concrete image-reference boundary for now. It has immediate value even before a semantic resolver exists: editor buttons can stop embedding raw SF Symbol strings throughout the view hierarchy, and semantic editor image defaults can be centralized.

The future design must decide whether semantic identity is added to `ImageReference` itself or represented by a separate image-resource type that resolves to `ImageReference`. Do not commit until we test actual needs. Requirements include:

- system symbol, asset-catalog image, bundled resource image, file-backed image, or no-image candidates;
- locale/culture/vendor overrides;
- writing-direction/mirroring behavior;
- accessibility labels independent of the visual candidate;
- decorative imagery that should be hidden from accessibility;
- fallbacks when a symbol is unavailable on a deployment target;
- template versus original rendering where that changes meaning.

### Semantic color

Color is part of presentation resolution even though it is not normally language localization. The key distinction is **semantic color role versus color value/source**.

- `SBJUIAppearance.invalidColor`, `changedColor`, `issueColor`, focus/search roles, etc. are semantic UI roles and belong on the presentation-resolution path.
- `ColorVariants` is currently a convenient source/construction vocabulary for `CodableColor`; it is not itself a semantic-role system.
- `CodableColor` may be persisted domain/user data and therefore must not be silently reinterpreted as a localized/theme color.

Semantic color resolution must account for theme/vendor overrides, light/dark appearance, increased contrast, differentiate-without-color, and any future application color vocabulary. A color may reinforce meaning, but never be the only carrier of state.

## Proposed ownership in SBJFoundation

SBJFoundation should own UI-independent presentation-resource semantics and resolver contracts because SwiftUI/UIVocabulary and SBJLayout already depend on Structure-level model semantics. Text is the first detailed resource family, with imagery and semantic color sharing the same context/override architecture where appropriate.

Working types/concepts:

```swift
SBJTextResource          // one conceptual piece of human-facing text
SBJTextCandidate         // one valid wording/presentation candidate
SBJTextCandidateRole     // standard/compact/abbreviated/etc.
SBJResolvedText          // renderer-ready text candidates, still not geometry-specific

// Names intentionally provisional:
SBJPresentationContext   // locale + vocabulary + imagery + theme/accessibility context
SBJPresentationResolver  // host-configured semantic resource resolution
SBJImageResource?        // semantic image identity resolving to ImageReference candidate(s)
SBJColorRole?            // semantic color identity resolving through appearance/theme
```

The exact names and type boundaries remain open. Text API shape first depends on the String Catalog extraction spike; image/color should share context/policy where useful without forcing all three resource families into one enum or protocol prematurely.

SBJFoundation should not own font measurement, Core Graphics drawing, PDF retry logic, or application-specific vendor/server policy.

## Existing Structure APIs that must collapse into the design

### `SBJPropertyMetadata.displayName`

`displayName` is currently generated as a human-readable `String`. It is presentation metadata and therefore eventually needs a localizable resource path.

The generated fallback from a Swift property name is useful for development, but dynamic un-camel-casing is not a complete localization strategy and may not be discoverable by String Catalog extraction. The design needs a fallback strategy that preserves today's low-maintenance behavior while allowing explicit/localizable overrides.

### `SBJPropertyInfo`

`title`, `summary`, `details`, `accessibilityLabel`, `accessibilityHint`, and `accessibilityValue` are currently `String` values.

They should eventually carry the shared text resource type while keeping declarations call-site friendly. This is the primary model-level association between a property and its complete user-facing explanatory/accessibility vocabulary.

Do not put accessibility metadata on every individual text candidate. Accessibility generally describes the property/control, not a particular rendered string.

### `Accessible` / `AccessibleItem`

These are already UI-independent and should stay that way. Their three `String?` properties should migrate to the shared resource type once that type exists.

SwiftUI's `View.accessibility(_:)` adapter remains a presentation adapter; it should resolve resources using the active text context before applying them.

### `AppInfo` application metadata

`AppInfo` currently mixes application metadata with presentation fallbacks. Its fields need to be classified explicitly during localization migration:

- `companyName` is framework/vendor-owned user-facing text and should become a localizable presentation resource rather than a hard-coded `String`.
- `supportEmail` is contact data and should remain verbatim, not localized.
- `supportURL` is a URL/contact value and should remain verbatim; it should also be represented as a URL rather than localized display text when the API is revised.
- `displayName` comes from bundle metadata and is user-facing. The bundle-provided value should remain the primary source; any application-supplied fallback must be a localizable presentation resource.
- `version`, `build`, `fullVersion`, and `bundleIdentifier` are technical/application metadata and must remain verbatim.
- `icon` is presentation imagery and should continue through the image/resource presentation path rather than text localization.

The current `"Unknown App"` / `"Unknown"` replacements for missing bundle values are also presentation decisions hiding loss of metadata. During this migration, remove those sentinel strings: preserve absence as `nil` for `displayName`, `version`, `build`, `fullVersion`, and `bundleIdentifier`, and let the consuming UI decide whether and how to present missing metadata. This prevents a technical accessor from injecting unlocalized English and preserves the distinction between absent data and a real value.

### Framework/editor vocabulary

The editor and UIVocabulary contain both compile-time literals and runtime strings. Examples include editor state labels, disclosure accessibility text, collection actions, issue UI, `SearchField`, `CollapsingMenu`, `PlaceholderMultilineTextField`, URL controls, `NumberTextField`, and `PendingAlert`.

The migration rule is not “replace every String with the new type.” Distinguish:

- framework-owned vocabulary -> localizable resource;
- model/user/runtime data -> verbatim or formatted resource;
- system action labels -> continue to delegate to the system where appropriate.

### `PendingAlert` / `Alertable`

This is a strong test case. `Alertable` currently returns runtime `String`s, so localization intent is already lost before the modifier presents them.

Eventually, title/message/action title should use the common text resource. The primary action should also become optional semantic state rather than using an empty button-title string as a control signal.

Framework-owned `"OK"` and system-owned cancel provide useful tests for the boundary between framework vocabulary and system localization.

### `NumberTextField`

The earlier standalone/editor split has now been resolved. `NumberTextField` is the reusable integer input control and `SBJIntegerEditor` composes it with structured-editor labeling/accessibility and the `Stepper`.

Its policy now deliberately matches `@SBJInteger`:

- a range describes validity rather than a clamping rule;
- out-of-range values remain inspectable and receive invalid chrome;
- no default-on-empty/default-on-invalid normalization policy is hidden in a formatter;
- numeric formatting uses the effective SwiftUI environment locale rather than captured `Locale.current`;
- grouping is disabled for editing while locale-specific numeric conventions remain available through `FormatStyle`.

The remaining localization concern is the text resource used for its title/placeholder. A future unit-aware field should compose the same numeric input behavior with typed measurement/unit formatting rather than creating another independent parser/editor.

### Enum/case presentation

`SBJCaseIterableEditor`, associated-enum presentation, and generated field labels currently derive user-facing strings from Swift names in several places.

This is useful zero-configuration fallback behavior, but dynamic derivation cannot be the only localization path. The design needs either explicit resources, generated resource metadata, or a verified catalog-discovery strategy without requiring a manually maintained enum of copy keys.

## Lessons from the app's `StringPresentable`

Jove's Characters currently has more than one hundred `StringPresentable` conformances. The protocol demonstrates several distinct responsibilities that the shared design must separate:

- full/default vocabulary (`description`);
- compact/domain abbreviation (`abbreviation`);
- alternate shape (`multiLineDescription`);
- raw-enum humanization via `uncamelCased`;
- composed values and punctuation;
- quantity/unit formatting;
- user/domain values that may contain verbatim content.

This is evidence that “localized String” is too small an abstraction.

Migration should classify each conformance instead of mechanically changing the protocol name. In particular:

1. vocabulary enums become localizable resources/candidates;
2. abbreviations become independent candidates when translation/domain conventions require it;
3. mechanically inserted line breaks become renderer policy where possible;
4. composed values become structured formatted/interpolated resources;
5. user-authored text remains verbatim.

## Composition and grammar

Current code frequently composes presentation with interpolation, comma joins, semicolon joins, bullets, and hand-built phrases. Some separators are visual layout; others encode English grammar.

The future resource system must make that distinction explicit enough that another language can reorder words and choose punctuation without forcing every caller into a bespoke localization API.

Do not attempt arbitrary post-localization substring replacement for jargon or terminology.

## Vendor, terminology, and server vocabulary

The resolver should support sparse host-supplied providers keyed by the same textual/semantic identity used by the base resource.

Examples:

- a vendor repackage changes a small set of labels while inheriting the rest;
- document settings choose one domain term over another;
- a server provides a semantic phrase/key that still needs app localization, formatting, and fitting;
- a server deliberately provides literal legal/user content that must remain verbatim.

The network layer must preserve which case it is. A server string should not accidentally become localizable merely because it flows through a text initializer.

## Context propagation

The shared `SBJPresentationContext` (working name) should be a value type that can be propagated using native mechanisms:

- SwiftUI: Environment;
- SBJLayout: its existing task-local render context;
- non-UI tools/tests: explicit parameter/context scope.

The value type should be shared; propagation mechanisms need not be.

Locale and other presentation policy must come from this context rather than assuming `Locale.current`, because previews/tests/document rendering may intentionally use a locale different from the device default.

## Fit-selection contract

Structure owns candidate meaning and preference. Renderers own geometry.

A fit consumer should be able to ask for candidates in preference order and select the best one that satisfies its constraints. It must not mutate the model to record the selected wording.

Important cases to test:

- different localized string lengths;
- custom fonts and Dynamic Type;
- one-line versus multi-line constraints;
- abbreviations that differ by locale;
- explicit localized break opportunities;
- right-to-left presentation;
- accessibility using full spoken semantics while visible text is compact.

## Search

Search is a separate but related concern. A user searching localized UI/model vocabulary generally expects the visible/localized term to match. Technical/raw values may still need search by stored representation.

Do not make search depend on rendered `Text`, but ensure the eventual resource resolver exposes suitable localized search text where model labels/options participate in search.

## Migration sequence

1. **String Catalog extraction spike** — prove the call-site shape and text-resource identity model before changing metadata types.
2. **Inventory semantic imagery/color** — keep editor controls on `ImageReference`/`SBJUIAppearance` boundaries and identify where semantic identity is still missing.
3. **Introduce shared text resource/candidate plus presentation-context contracts** in Structure with localizable and explicit-verbatim construction.
4. **Migrate Structure-owned vocabulary** and add SwiftUI text resolution adapters.
5. **Migrate `SBJPropertyInfo`, `Accessible`, `AccessibleImage`, and generated display names** while preserving easy declarations and distinct spoken/visual channels.
6. **Connect SBJLayout** so `JCSText` consumes shared text resources/candidates and the render context carries the shared presentation context.
7. **Replace app `StringPresentable` incrementally**, classifying each conformance rather than flattening it.
8. **Add semantic image/color providers** once resource identity/context precedence is stable; retain `ImageReference`, `ColorVariants`, `CodableColor`, and `SBJUIAppearance` in their appropriate candidate/value/role jobs.
9. **Add vendor/document/server providers** across text/image/color where the host actually needs them.
10. **Add unit-aware presentation/editing** on top of the typed formatting layer rather than as a parallel system.

## Required design spikes before API commitment

- Verify Xcode String Catalog extraction for the proposed wrapper/initializer forms.
- Verify interpolation/`FormatStyle` preservation through the wrapper.
- Decide whether resource identity can be recovered from `LocalizedStringResource` or must be stored explicitly.
- Decide how dynamic/generated property and enum fallback labels enter the catalog without a manually maintained key enum.
- Decide how sparse vendor/document providers refer to an interpolated resource identity.
- Decide whether resolved candidates are plain `String`, `AttributedString`, or a small value carrying additional direction/layout metadata.
- Verify Asset Catalog/localized-image behavior and what can be delegated to the system versus what needs semantic image resolution.
- Verify SF Symbol RTL/mirroring behavior for the symbols actually used by the framework and identify culturally semantic cases that require explicit alternatives.
- Decide whether semantic image identity belongs inside an evolved `ImageReference` or in a separate resource resolving to `ImageReference`.
- Decide how semantic color roles relate to `SBJUIAppearance`, app/vendor themes, asset colors, and persisted `CodableColor` values without conflating them.

## Non-goals

- Do not replace persisted model values with localized strings, image names, or semantic theme colors.
- Do not make SBJFoundation's shared presentation-resource model measure PDF fonts or geometry; that belongs in SBJLayout.
- Do not require a central enum of every localized phrase.
- Do not reintroduce SBJLayout `Jargon` as the shared solution.
- Do not assume server-provided text is automatically authoritative, localizable, or verbatim; preserve its declared semantics.


## Current implementation checkpoint

As of this design revision:

- SubjectEditor button imagery is routed through `ImageReference` via centralized semantic editor image defaults instead of embedding SF Symbol strings at button call sites.
- `NumberTextField` is the canonical reusable integer field and `SBJIntegerEditor` consumes it; the legacy clamping/default formatter split is gone.
- `SBJUIAppearance` remains the current semantic color-role boundary.
- `AccessibleImage` / `AccessibleImageItem`, `ImageReference`, and `ColorVariants` are explicit inputs to the future presentation-resource design rather than unrelated utility types.

## Finalization spike results and implementation baseline

The September 2026 design-finalization pass closed the architectural questions that can be answered without Xcode-specific extraction tooling and folded the completed pre-localization audit into this document.

### String Catalog/API shape

The source-level resource initializer should take `LocalizedStringResource` rather than making the SBJ wrapper itself the string-literal type:

```swift
public init(_ resource: LocalizedStringResource)

// call site
SBJTextResource("Armor Class")
```

This preserves the desired source-string call site while making the literal resolve to Apple's localization type. Apple documents `LocalizedStringResource` as a deferred localization reference carrying key, default value, table, bundle and locale, and as supporting string interpolation. This makes it the right underlying source representation for ordinary localizable candidates.

Do **not** make the first implementation depend on `SBJTextResource: ExpressibleByStringLiteral`. That changes the literal's inferred type to the wrapper and creates an unnecessary String Catalog extraction risk.

One Xcode-only verification remains mechanical rather than architectural: build a fixture containing the initializer above and confirm the literal is emitted into an `.xcstrings` catalog. The available non-Apple Swift toolchain cannot import `LocalizedStringResource`, so that extraction step cannot be executed here. The API is deliberately shaped so that failure of this verification requires changing only the convenience initializer, not the resource model.

### Resource identity

Ordinary localizable text does not need a giant application enum of keys. The default identity is the localization resource identity: bundle/table/key, with source/default wording retained by `LocalizedStringResource`.

The shared resource should also permit an **optional explicit semantic identity** for the minority of resources whose override identity must remain stable even if source wording or catalog organization changes. Vendor/document/server override providers operate on semantic/resource identity, never on substring replacement of resolved prose.

### Interpolation and formatting

Localized interpolation must remain typed. A localizable candidate may therefore contain Apple's `LocalizedStringResource` interpolation or an SBJ formatting recipe that retains typed arguments until resolution. Runtime/user-authored strings embedded in localized grammar must be marked verbatim arguments rather than converted into independently localizable literals.

The resource layer must not make `String` concatenation the primary composition mechanism for values such as numbers, dates, units, dice, currency or lists.

### Candidate model

The first candidate vocabulary remains deliberately small:

- `standard`
- `compact`
- `abbreviated`

Each authored candidate is independently localizable. Plain wrapping, truncation, hyphenation and line-count constraints are renderer behavior and do not create new semantic candidates. A multiline candidate exists only when the authored wording/break semantics are intentionally different.

### Resolver model

`SBJPresentationContext` is a value describing the effective presentation inputs. Resolver precedence is host-configured through an ordered sparse provider chain rather than hard-coded globally. Locale, vendor, document terminology, user settings, server policy, accessibility and unit/format preferences are independent axes.

SwiftUI may propagate the context through the environment; SBJLayout may place it in its task-local render context; tests and tools may pass it explicitly. None of those propagation mechanisms changes the semantic model.

### Audited remaining Foundation seams

The completed source audit found the following active migration seams:

- `Localization/StringPresentable.swift`, `Units+StringPresentable.swift`, and `Array+bulleted.swift` retain the legacy string-presentation abstraction.
- `Localization/Jargon.swift` remains only as legacy sparse-terminology evidence; new terminology behavior belongs in the presentation resolver.
- `NumberTextField`, `SBJDecimalEditor`, and `SBJLosslessNumericEditor` are the remaining numeric-formatting seams. Existing effective-locale behavior should be preserved while formatting moves behind presentation context.
- `PendingAlert`, `SBJIssue`, `Accessible`/`AccessibleImage`, `SBJPropertyInfo`, and editor-owned labels/hints are the primary framework-owned text clients.
- `ImageReference` remains the concrete image-reference boundary; `SBJUIAppearance` remains the semantic UI-color boundary.
- `Data+Hex` invariant hexadecimal formatting is technical formatting and is not a localization migration target.

No separate pre-localization audit document is retained. Future implementation notes belong in this design, `UNITS.md`, `TESTING.md`, or the relevant SBJStructure documentation only when they describe an enduring contract.

