# SBJStructure Sample Coverage

`SBJStructureSampleModel.swift` is the canonical **compile/sample fixture** for the
SBJStructure subsystem of SBJFoundation. `SBJStructuredEditorPreview.swift` and
`SBJEditFieldPreview.swift` both render that same model. The fixture is allowed to
be contrived: its job is to keep framework coverage visible while still providing
a usable editor example.

SBJFoundation is broader than SBJStructure and also contains reusable platform/application-foundation utilities. General-purpose
foundation/UI utilities do not have to be forced into the sample merely to be
covered, but anything outside the sample editor dependency path must have a clear useful
purpose or be explicitly marked for review.

This document lives with the SBJStructure subsystem under `SBJStructure/Documentation/`.

## Coverage definition

There are two rules.

### Annotation coverage

**Every SBJStructure annotation must be literally declared somewhere in
`Preview/SBJStructureSampleModel.swift`.**

The sample model does not need to exercise every annotation parameter or every enum
case. One representative declaration is enough to make the annotation itself part
of the sample's compile surface. If a new annotation is added, the canonical sample
model is incomplete until it declares it.

### Type/file coverage

A framework type or source dependency is considered covered when the Preview's
compile path reaches it, directly or transitively, without relying on an external
application plug-in/strategy.

The practical test is:

> If this code type were removed, would the SBJStructure sample editor still build?

Examples:

- `CodableColor` is covered because the sample model declares a `CodableColor`
  property and the editor dispatches through the color-editor path.
- `CodableFont` and `CodableFontCache` become covered transitively because the
  Preview declares `@SBJPresentation(.fontFamily)` and the font-family editor uses
  the cache/type.
- collection mutation helpers used by the Set/Dictionary editors are covered even
  though the Preview does not spell their method names.
- an enum does **not** need every case exercised. Removing the enum type must break
  the Preview build; removing one unused case is outside this definition.
- sharing a file with a covered type is not sufficient. A type can therefore be
  outside the Preview dependency path while still being an intentional App Foundation
  API with real application consumers. `ColorVariants` is an example.

This is compile dependency coverage, not runtime branch coverage and not test
coverage. Focused tests remain appropriate for parameter combinations, edge cases,
and behavior.

## Annotation checklist

The canonical sample model currently declares every annotation in
`Sources/SBJFoundation/SBJStructure/Public/Annotations`:

- `@SBJStructure` — structs and an associated-value enum.
- `@SBJArray` — ingredients and steps.
- `@SBJColor` — recipe-card tint.
- `@SBJData` — a small import fingerprint, exercising Data invariants/editor.
- `@SBJDate` — last-made date.
- `@SBJDesignatedInit` — `SBJStructureSampleNutrition` initializer. This is intentionally
  present even though its primary consumer is Swift-source export.
- `@SBJDictionary` — substitutions.
- `@SBJEditorProperty` — editor-only computed display-name adapter.
- `@SBJInteger` — servings and time fields.
- `@SBJNotEditable` — import source.
- `@SBJNumber` — nutrition/ingredient quantities.
- `@SBJOptional` — source URL presence requirement.
- `@SBJPresentation` — recipe-card font family.
- `@SBJSet` — tags.
- `@SBJString` — single-line, multiline, and sheet-edit examples. The annotation is
  the coverage unit; multiple styles are retained because they exercise distinct
  editor paths and are useful visually.
- `@SBJURL` — network-only source URL.
- `@SBJUUID` — nonzero identifier.
- `@SBJUnitValue` — nonnegative serving volume.

When an annotation is added or removed, update this checklist and
`SBJStructureSampleModel.swift` in the same change.

## Major dependencies covered transitively by the sample editor

The sample editor's compile path reaches substantially more than the declarations visible
in the fixture. Important examples include:

- generated `SBJStructured`, `SBJEditable`, `SBJSwiftUIEditable`, and associated-enum
  conformances/metadata;
- structural comparison, content inspection, default-value creation, invariant
  checking, validation key paths, issues/diagnostics, and traversal/search state;
- scalar and collection typed-editor dispatch, bindings, row/disclosure chrome,
  field sizing, changed/empty/invalid state, accessibility semantics, and editor
  search;
- Set replacement and Dictionary key-renaming mutation helpers;
- Data hex parsing/formatting through `@SBJData` / `SBJDataEditor`;
- UUID parsing/zero checking through `@SBJUUID`, validation, and `SBJUUIDEditor`;
- URL parsing/open behavior and `URLButton` through `@SBJURL` / `SBJURLEditor`;
- `CodableColor` and color editing;
- `CodableFont` / `CodableFontCache` through the font-family presentation editor; directory placement does not affect this transitive coverage;
- `PlaceholderMultilineTextField` and shared multiline chrome through
  `@SBJString(.sheetEdit)`;
- `SBJCompactMenuLabel`, `SBJUIAppearance`, focus/invalid modifiers,
  `SearchField`, and other UIVocabulary used by editor implementations;
- Swift-source encoder types referenced by the `SBJStructured` contract and the
  designated-initializer metadata path.

The important point is not whether the Preview names these APIs. If removing the
code type breaks a file on the Preview dependency path, it is covered by this
working definition.

## Not covered by the sample editor, but valid App Foundation

The following are intentionally outside the Preview dependency path today. Their
absence is not a problem because each has a useful application-foundation role.
They should not be inserted into the sample model merely to force compile coverage.

### Persistence / observation

- `DefaultsStorage`, `DefaultsStorageValue`, `PropertyListType` — typed
  `UserDefaults` persistence.
- `ObserveToken` / `observeValue` — bridge Observation changes to controller/app
  callbacks with explicit cancellation/lifetime behavior.

### General UI vocabulary

- `ColorVariants` — application-facing color-source vocabulary used by SBJ applications.
  It remains intentionally valid outside the sample editor even though the sample does not
  require it. It is also an input to the presentation-resource/color design.
- `ImageReference` — **covered transitively by the sample editor** because editor button, status,
  and disclosure imagery now routes through the `ImageReference` boundary. It also remains
  general application-facing UI vocabulary.
- `CollapsingMenu` — collapse one-or-many actions into the appropriate toolbar/menu
  presentation.
- `NumberTextField` — **covered transitively by the sample editor** because
  `SBJIntegerEditor` uses it as the canonical reusable integer input. Range validity,
  locale formatting, chrome, sizing, and keyboard behavior therefore share one
  implementation; the structured editor adds its property label/accessibility and Stepper.
- `PendingAlert` / `Alertable` / `.pendingAlert(...)` — reusable alert state and
  view presentation; also a concrete input to the localization design.
- `URLText` — reusable read/display URL presentation. (`URLButton` itself is
  covered by the URL editor.)
- `AccessibleImage` / `AccessibleImageItem` — reusable image accessibility model.

### General Foundation/system extensions
- `IdentifiableImage` / UIImage conveniences — identity/loading helpers for UIKit
  image consumers.
- filename sanitization helpers — filesystem-safe user/document names.
- generic String parsing conveniences (`unjoined`, `signedDescription`,
  `isEquivalent`, replacement-table helper) — app/domain string utilities.
- NSError/process-environment diagnostic conveniences — debugging/platform
  helpers.

These are good candidates for a SBJFoundation documentation section rather
than SBJStructure sample examples.

## Policy for new code

For each new framework addition:

1. **Is it an annotation?**
   - Declare it in `SBJStructureSampleModel.swift`, even if the fixture must be
     contorted to do so.
2. **Does the existing Preview/editor compile path reach the new type?**
   - If yes, it is covered under this document's definition.
3. **If not, is it a useful App Foundation primitive?**
   - Keep it outside the sample and record its purpose here (or in the future
     App Foundation documentation).
4. **If not covered and there is no clear independent use?**
   - Add an explicit source comment marking it for API review. Do not let it appear
     covered merely because it shares a file with something the Preview uses.

The canonical model is therefore deliberately a kitchen-sink **SBJStructure
integration fixture**, while App Foundation utilities remain separate when forcing
them into the sample would test nothing about SBJStructure.

## Standalone editor fixture

`SBJEditFieldPreview.swift` complements the structural fixture with a different
contract: each stock editor-selection category must be constructible from an
ordinary SwiftUI binding without going through `SBJEditorView`. It binds to `SBJStructureSampleModel`, the same model used by the automatic preview.
Dispatch-only properties that would make the automatic form noisy are kept on that
model with `@SBJNotEditable`; the standalone preview can still bind to them directly.

When a new stock `SBJValueEditor` selection path is added, add a corresponding
`SBJEditField` example so standalone usability remains a compile-visible design
contract. The preview also exercises `SBJEditField(root:keyPath:)`, which is the
same rendering primitive used by the automatic structured editor, making that
relationship a compile-visible constraint rather than only an architectural intention.
