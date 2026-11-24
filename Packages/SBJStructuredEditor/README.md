# SBJStructuredEditor

`SBJStructuredEditor` provides reusable SwiftUI editors for models that conform to `SBJMutableStructure`. It consumes structural metadata from `SBJStructure`; it does not define domain meaning or generate model metadata itself.

## Getting started

```swift
import SwiftUI
import SBJStructure
import SBJStructuredEditor

struct ModelEditor<Model: SBJMutableStructure>: View {
    @Binding var model: Model
    let presentation: SBJEditorPresentationModel

    var body: some View {
        SBJEditorScrollView(presentationModel: presentation) {
            SBJEditorView(value: $model, presentationModel: presentation)
        }
    }
}
```

Create a `SBJEditorPresentationModel` for the editing session and retain it while the view is presented. `SBJEditorView` exposes editor rows without prescribing the host scroll container. `SBJEditorScrollView` adds issue navigation and scrolling; `SBJEditorSearchView` can be hosted separately to provide search and filters.

When the same SwiftUI view identity can edit different documents, supply a stable `documentID` to `SBJEditorView` so the changed-only comparison baseline resets when switching documents, not on every edit.

## Ownership and dependencies

- `SBJLocalization`: semantic labels, accessibility metadata, and domain-level invariants.
- `SBJStructure`: structural metadata, validation, model construction, traversal, and collection mutation.
- `SBJUIVocabulary`: reusable buttons, fields, and presentation controls (including merged sharing UI).
- `SBJLayout`: layout support.
- `SBJHelp` and `SBJFileResources`: optional bundled help and file resources.
- `SBJStructuredReport`: report catalog and PDF presentation used by the editor's structure-report affordance.

This package owns UI bindings, control selection, disclosure, validation presentation, editable projections, and editor-only navigation. It does not depend on `SBJStructuredAI`, and it does not own AI-to-visual field identity.

## Controls and editing behavior

The editor provides controls for text, numbers, dates, URLs, colors, booleans, enums, optional values, unit values, and collections. `SBJEditorRegistry` lets a client override controls and value creation. Registry-specific creators take precedence over default structural construction.

Array actions resolve the **current** collection position when invoked, rather than trusting an old row index. Sets and dictionary entries apply uniqueness checks; some collection insertions are unavailable when valid choices are exhausted. Invalid numeric or URL drafts remain in the editing control until a valid value can be committed; they do not overwrite the bound model with invalid data.

Writable stored properties are edited through `SBJStructure` metadata. Annotated writable computed properties can appear as presentation-only fields. Immutable properties are not made writable by the editor.

## Search, issues, and navigation

Text search and changed/empty filters are presentation controls over structural search semantics. `SBJEditorPresentationModel` coordinates expansion and issue navigation. An issue navigation target uses human-readable path components; it is **not** a stable serialized collection-aware field identity. The proposed external AI field-attention integration remains deferred.

## Help and structure report

The `SBJStructuredEditorNomenclature` and `SBJStructuredEditorSymbology` sets provide shared client-visible metadata. `SBJHelpConfiguration.structuredEditorHelp` registers editor and structure-report nomenclature and symbols. `SBJStructuredReport` supplies the report viewer without moving report functionality into this package.

## Platform behavior and tests

Interactive editor views are unavailable on watchOS and tvOS. Shared model/validation behavior belongs to lower-level packages and is tested there. Editor tests focus on projection, binding, collection mutation, navigation state, and creation rules—not the compiler, exact wording, or SwiftUI rendering snapshots. Interactive focus and scrolling should also be checked in a host application on supported platforms.

See [Architecture](Documentation/Architecture.md), [Public APIs and construction](Documentation/PublicApiAndConstruction.md), [Traversal and rendering](Documentation/TraversalAndRendering.md), and [Controls and test coverage](Documentation/ControlsAndTestCoverage.md).
