# Editor guide

The SwiftUI editor and `@SBJEditable` live in **SBJFoundation**. Structural metadata, constraints, validation, and `@SBJStructure` live in **SBJDataDefinition**. A model annotated with `@SBJEditable` receives both structural and editor generation.

# Generic SwiftUI editor

The editor is generated from the same structural declarations. It is intended to remain useful without becoming a second schema system.

## Hostable editor pieces

The current API separates editor content from search/filter controls and from scrolling/layout ownership:

```swift
@State private var editorState = SBJEditorPresentationModel()

VStack(spacing: 0) {
    SBJEditorSearchView(
        value: recipe,
        presentationModel: editorState,
        registry: registry
    )

    SBJEditorScrollView(presentationModel: editorState) {
        SBJEditorView(
            value: $recipe,
            presentationModel: editorState,
            registry: registry
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
```

The host still owns margins, toolbars, inspectors, sheets, and surrounding chrome. `SBJEditorScrollView` is the stock scrolling policy: it observes `SBJEditorPresentationModel.navigationTarget`, lets the editor expand the target's ancestor disclosures, and scrolls the requested property into view. This is what lets the issue viewer's trailing chevron dismiss the sheet and jump directly to the affected property.

Clients with a specialized scrolling container may continue to host `SBJEditorView` directly. In that case they own the final scroll operation and can observe `SBJEditorPresentationModel.navigationTarget`; the editor still uses the target to reveal collapsed ancestors. `SBJCodableEditor` / `SBJCodableEditorCore` use `SBJEditorScrollView` automatically.

For deeply nested, dynamically sized content, `SBJEditorScrollView` (or an equivalent `ScrollView`/stack host) is generally preferable to a list-backed `Form`, because the editor contains rows whose heights can change substantially during search, disclosure expansion, and issue navigation.

## Search and filtering

`SBJStructuralSearchCriteria` groups search/filter state so new criteria can be added without threading separate booleans throughout the recursive renderer.

The stock search view supports:

- text search;
- changed-only filtering;
- empty-content-only filtering;
- on-demand issue inspection.

Search input is debounced before invalidating a large editor tree. Visible fields are filtered into editor snapshots before their expensive views are constructed.

Search semantics are also extensible outside SwiftUI. `Predicated` lets a value own its matching behavior, while `SearchProtocol` exposes first-class searchable text. The structural matcher uses those protocols before falling back to recursive inspection.

## Identity, index paths, and snapshots

The editor uses collection-view-style structural concepts:

```swift
SBJEditorItemIdentifier   // who
SBJEditorIndexPath        // where
SBJEditorSnapshotItem     // identifier + position + current content
SBJEditTraversalContext   // recursive traversal context
```

This distinction matters for reactive rendering:

```text
ingredient-42 at ingredients[2]
        ↓ reorder
ingredient-42 at ingredients[0]
```

The index path changed; the logical item did not.

Search/filtering similarly changes the visible snapshot without redefining the underlying item identifiers.

## Changed, empty, and validation state

Editor rows expose structural state rather than mutation history:

- changed — current value is not structurally equal to the original snapshot;
- empty — `hasContent == false`;
- invalid — explicit invariant evaluation reports an issue.

The stock search bar uses the same status symbols as the rows, so the filter controls also act as a legend.

## Custom application types

`SBJEditorRegistry` supplies exact-type and exact-property customization without changing the structural model.

### Register an editor

```swift
var registry = SBJEditorRegistry()
registry.register(RecipeRating.self) { label, value, _ in
    RecipeRatingEditor(label: label, value: value)
}
```

### Decorate one property while keeping its normal editor

```swift
registry.registerLineItem(\MealRecipe.name) { label, value, defaultContent, _ in
    HStack {
        defaultContent
        // application-specific decoration
    }
}
```

### Override one property's binding

```swift
registry.registerBinding(\MealRecipe.recipeCardTint) { recipe in
    Binding(
        get: { recipe.wrappedValue.recipeCardTint },
        set: { color in
            recipe.wrappedValue.recipeCardTint = normalizeBrandColor(color)
        }
    )
}
```

### Register a creator

```swift
registry.registerCreator(RecipeIngredient.self) {
    RecipeIngredient(name: "New ingredient")
}
```

A custom exact-type editor takes precedence over built-in rendering. Registry customization is application/UI policy; it does not alter structural metadata.

## Simple enums

A `CaseIterable & Hashable` enum is rendered as a picker without an SBJ-specific editor protocol:

```swift
enum RecipeCourse: String, Codable, CaseIterable, Hashable {
    case breakfast
    case lunch
    case dinner
    case dessert
}
```

## Associated-value enums

`@SBJStructure` can annotate a Codable enum directly:

```swift
@SBJStructure
enum RecipeHeatSetting: Codable {
    case none
    case oven(celsius: Int, convection: Bool)
    case burner(level: Int)
}
```

The editor renders a case selector and recursively generated associated-value controls. Changing an associated value reconstructs the selected case while preserving its other associated values.

`SBJDefaultValue` is the UI-independent type-erased factory used for context-free associated values and other generic creation. `SBJEditorRegistry` layers application-specific creators on top.

---

