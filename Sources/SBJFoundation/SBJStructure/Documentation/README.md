# SBJStructure

SBJStructure is the structured-model and SubjectEditor subsystem of **SBJFoundation**. It is a Swift facility for describing the **structure** of `Codable` models separately from the business semantics layered on top of them.

It began from a recurring problem: Swift gives us excellent language-level tools for types, coding, equality, initialization, collections, and errors, but applications often quietly overload those tools with meanings they were not designed to carry. A model's `Equatable` conformance becomes an accidental persistence comparison. `.isEmpty` becomes a proxy for whether a value is meaningful. A throwing initializer becomes the only place validation can happen. UI metadata is copied into a second schema. Reactive views invent their own identity rules.

Those shortcuts are convenient until two meanings diverge. Then the same abstraction that removed a little code creates bugs in editing, migration, validation, persistence, testing, or UI state.

SBJStructure gives those concerns explicit names and generated implementations.

```swift
@SBJStructure
struct MealRecipe: Codable {
    @SBJString(minLength: 1, maxLength: 80)
    var name: String

    @SBJInteger(range: 1...24)
    var servings: Int

    @SBJArray(
        reorderable: true,
        title: \RecipeIngredient.name,
        uniqueBy: \RecipeIngredient.id
    )
    var ingredients: [RecipeIngredient]
}
```

From the model declaration, SBJStructure can provide structural metadata, recursive content semantics, explicit invariant validation, structural equality, diagnostics, source export, and a live SwiftUI editor. The model remains ordinary Swift: annotated properties are not wrapped, getters and setters are not intercepted, and validation is never imposed automatically.

`SBJCodableEditor` is one consumer of the structural model. It is useful during prototyping, testing, debugging, and internal or personal applications, but the editor is **not** the purpose of the framework.

See `Preview/SBJStructureSampleModel.swift` for the canonical SBJStructure sample fixture. Both `SBJStructuredEditorPreview` and `SBJEditFieldPreview` use that same model, and focused integration tests reuse it through `@testable import`. It intentionally declares every SBJStructure annotation. [`SAMPLE_COVERAGE.md`](SAMPLE_COVERAGE.md) defines the stricter coverage rule, and [`ORGANIZATION.md`](ORGANIZATION.md) documents the source layout.

Design and architecture documents live under `Documentation/SBJStructure/`. The root README remains the package entry point; detailed design, regression, coverage, and migration notes belong in that directory. This directory convention should be used by related SBJ projects as they are reorganized.

---

## Why SBJStructure exists

### 1. Structural concerns and business concerns are different concerns

The framework deliberately separates concepts that are often blended together:

| Structural concept | It is **not** the same as | Why the distinction matters |
| --- | --- | --- |
| `hasContent` | `.isEmpty`, `nil`, count, or zero | A nonempty value may still contain no meaningful domain content. |
| `sbjStructuralEquals` | business `Equatable` | Business equality may intentionally ignore, normalize, or reinterpret stored state. |
| `invariant(at:)` | a failable/throwing initializer | Whether invalid state is acceptable depends on the call site and lifecycle. |
| coded membership | editability | A property may be structural but intentionally read-only in a generic editor. |
| constraints | presentation hints | A rule such as `1...24` is different from a suggestion such as multiline editing. |
| property documentation | UI implementation | Documentation and accessibility belong to the model's description, not one screen. |
| item identifier | index path / slot | A logical item can move without becoming a different item. |
| default creation | domain construction | Generic tools may need a context-free starter value even when production creation uses richer domain APIs. |

This vocabulary is one of the main products of the library. Once the meanings are distinct, code can choose the right one instead of relying on accidental equivalence.

### 2. Model rules and documentation should be DRY

A property should not have one declaration for coding, another for validation, another for an editor, another for documentation, and another for test tooling.

SBJStructure treats the Swift/Codable model as the schema. Property annotations **refine** that schema with information Swift does not already express:

```swift
@SBJString(.multiline, maxLength: 2_000)
var notes: String

@SBJArray(minCount: 1, uniqueBy: \RecipeIngredient.id)
var ingredients: [RecipeIngredient]
```

The same declaration can be consumed by validation, diagnostics, generic editors, documentation views, import/export tools, source generation, tests, or application-specific tooling.

There is no parallel field-builder schema to keep synchronized.

### 3. Validation is a call-site concern

The model declares its invariants. The **caller** decides what to do with them.

Different call sites legitimately need different policies:

```swift
// Fail fast at a boundary.
try recipe.invariant(at: \MealRecipe.self)

// Probe only during development; no release-build work.
try recipe.debugInvariant(at: \MealRecipe.self)

// Inspect and keep going.
let issues = SBJStructureDiagnostics.issues(for: recipe)

// Or intentionally do nothing yet while decoding, migrating, editing, or repairing.
```

The framework therefore does not reject ordinary assignment:

```swift
recipe.servings = 99   // ordinary Swift assignment; permitted
```

The declaration says `99` violates the model invariant. It does not say every intermediate state in every workflow must be rejected immediately.

This is especially important for editors, migrations, recovery tools, partially decoded data, and tests that need to construct invalid cases deliberately.

### 4. Prefer atomic construction over builders and multi-step initialization

SBJStructure leans toward model values that can be constructed in one meaningful operation rather than requiring a mutable builder lifecycle.

That philosophy is compatible with explicit validation: an initializer can construct a value atomically without being forced to define every validation policy for every caller.

`@SBJDesignatedInit` lets Swift source export reconstruct a value through the initializer that represents its intended construction API. `sbjDefaultValue()` and `SBJDefaultValue` serve a narrower tooling purpose: they provide a context-free starter value when one exists, without turning the domain model into a builder.

### 5. The core abstractions should cost nothing when they are not used

SBJStructure's annotations are macros and metadata declarations, not runtime property wrappers. They do not intercept ordinary reads or writes and do not insert validation into assignment.

Generated structural operations are normal Swift functions and static metadata. Consumers pay for validation, structural comparison, diagnostics, source export, or editor presentation **when they invoke those operations**. `debugInvariant` compiles to a no-op outside `DEBUG`.

This is the sense in which SBJStructure aims for zero-cost structural abstractions: declaring the model does not put a tax on normal property access or require a runtime schema engine in the hot path.

### 6. A living structural editor is valuable during design

During prototyping and testing, the fastest way to discover whether a model actually works is often to edit the real structure.

`SBJEditorView` recursively renders the same structural declarations used by the rest of the framework. It supports validation diagnostics, changed/empty indicators, search/filtering, optionals, collections, nested structures, enums, documentation, accessibility, custom editors, and application-provided creators.

For production customer-facing interfaces, the generic editor may only be a development tool. For internal, administrative, diagnostic, personal, or small applications, it may be entirely sufficient as the shipped editor.

Hand-built forms can reuse the same stock value editors without hosting a generated object editor. ``SBJEditField`` has two useful modes. The binding form accepts any ordinary SwiftUI `Binding` and selects the same stock editor used by `SBJEditorView` for that value type:

```swift
struct RecipeHeaderView: View {
    @Binding var name: String
    @Binding var servings: Int
    @Binding var lastMade: Date

    var body: some View {
        VStack {
            SBJEditField("Name", value: $name)
            SBJEditField("Servings", value: $servings, integerRange: 1...24)
            SBJEditField("Last made", value: $lastMade)
        }
    }
}
```

When the binding is a property of an `SBJSwiftUIEditable` model, prefer the model-aware form:

```swift
SBJEditField(root: $recipe, keyPath: \.servings)
```

The root/key-path form derives the label and editor configuration from the property's generated structural metadata, honors key-path-specific registry binding and whole-line overrides, applies property help and text-input policies, and participates in the same navigation/visual-effectiveness rendering path as the automatic editor. The automatic editor itself renders structured properties through this same `SBJEditField` path.

The plain binding form does not require an `@SBJStructure` root. It supports the built-in scalar editors, optionals, collections, CaseIterable values, associated-value enums generated by `@SBJStructure`, nested `SBJSwiftUIEditable` values, unit values, and exact-type overrides from `SBJEditorRegistry`. Presentation arguments such as `textStyle`, numeric/date ranges, color alpha support, and collection reordering expose the same stock hints directly when no model metadata is available.

`SBJEditFieldPreview.swift` is the standalone component fixture. It binds every supported stock editor category to properties on an example model, and also contains model-aware root/key-path examples, so leaf and recursive editors can be previewed without `SBJEditorView`.

Either way, the structural model does not depend on the editor.

### 7. Reactive UI needs structural identity and position, not just values

Reactive UI has to answer several different questions at once:

- **Which logical item is this?**
- **Where is it currently presented?**
- **What content is it showing now?**
- **What accessibility semantics describe it?**

SBJStructure uses collection-view-style terminology for these concepts:

- `SBJEditorItemIdentifier` — stable logical identity.
- `SBJEditorIndexPath` — current presentation location.
- `SBJEditorSnapshotItem` — item identifier + index path + current content.
- `Accessible` / `AccessibleItem` — presentation-independent accessibility semantics.

An element can move from index 2 to index 0 while retaining the same item identifier. Search can produce a different visible snapshot without changing logical identity. These types are `Hashable` where identity/state systems need hashing, rather than using display position or current content as accidental identity.

For arrays, `uniqueBy:` provides a natural stable element identifier when the model has one:

```swift
@SBJArray(
    reorderable: true,
    title: \RecipeIngredient.name,
    uniqueBy: \RecipeIngredient.id
)
var ingredients: [RecipeIngredient]
```

---

## Structural model: Codable is the schema

`@SBJStructure` treats coded stored properties as structural membership.

If the model declares `CodingKeys`, those keys are authoritative. Without `CodingKeys`, eligible stored properties participate automatically.

A property does **not** need an SBJ annotation just to be part of the model:

```swift
@SBJStructure
struct Document: Codable {
    var title: String       // structural and editable without @SBJString
    var modified: Date     // structural and editable without @SBJDate
    var identifier: UUID   // structural and editable without @SBJUUID
}
```

Property annotations are refinements. Use them only when the model has something additional to say: a constraint, usage hint, or editor-specific membership choice.

As a style rule, avoid annotations that add no effective information.

`SBJEditableField` is the corresponding **UI-independent writable descriptor**. It exposes the writable key path plus structural behaviors such as search matching, changed-state comparison, content inspection, and validation. `SBJEditorPropertyDescriptor` is public only because `@SBJStructure` must emit it into the client module; it is macro-facing infrastructure for automatic traversal, filtering, and type erasure. Actual property rendering is delegated to the public `SBJEditField` component. That split allows alternate editors or mutation tools to reuse generated editability without depending on SwiftUI.

---

## A complete example

```swift
enum IngredientUnit: String, Codable, CaseIterable, Hashable {
    case gram, kilogram, milliliter, liter
    case teaspoon, tablespoon, cup, item
}

@SBJStructure
struct RecipeIngredient: Codable, Hashable {
    var id = UUID()

    @SBJString(minLength: 1, maxLength: 60)
    var name = "New ingredient"

    @SBJNumber(range: 0...2_000)
    var quantity: Decimal = 1

    var unit: IngredientUnit = .item
    var preparation: String? = nil
}

@SBJStructure
struct MealRecipe: Codable {
    @SBJString(minLength: 1, maxLength: 80)
    var name = "Roasted Vegetable Pasta"

    @SBJString(.multiline, maxLength: 400)
    var summary = "Roasted vegetables tossed with pasta and olive oil."

    @SBJInteger(range: 1...24)
    var servings = 4

    var vegetarian = true
    var lastMade: Date? = nil
    var sourceURL: URL? = nil

    @SBJArray(
        reorderable: true,
        title: \RecipeIngredient.name,
        minCount: 1,
        maxCount: 30,
        uniqueBy: \RecipeIngredient.id
    )
    var ingredients: [RecipeIngredient]

    @SBJSet(maxCount: 12)
    var tags: Set<String> = []

    @SBJString(.multiline, maxLength: 1_000)
    var notes: String? = nil
}
```

---

## Generated structural API

A struct annotated with `@SBJStructure` conforms to `SBJStructured`, which refines `Codable`, `HasContentCheckable`, and `SBJStructuralComparable`.

The macro generates structural metadata and default behaviors such as:

```swift
static var sbjProperties: [SBJPropertyMetadata<Self>] { get }
static var sbjEditableFields: [SBJEditableField<Self>] { get }

@MainActor
static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] { get }

var _hasContent: Bool { get }
var hasContent: Bool { get }

func _invariant(at keyPath: SBJValidationKeyPath) throws
func invariant(at keyPath: SBJValidationKeyPath) throws

func _sbjStructuralEquals(_ other: Self) -> Bool
func sbjStructuralEquals(_ other: Self) -> Bool

static func sbjDefaultValue() -> Self?
```

Associated-value enums also receive generated case/editor construction metadata and Swift-source-export support.

### The underscore convention: generated default + intentional override

Several behaviors use the same pattern:

- `_hasContent` → generated structural content calculation.
- `_invariant(at:)` → generated recursive and annotation-based invariant checks.
- `_sbjStructuralEquals(_:)` → generated field-by-field structural comparison.

The public member normally forwards to the generated underscore member. A model can declare the public member itself to extend or replace the default:

```swift
var hasContent: Bool {
    isTemplate || _hasContent
}

func invariant(at keyPath: SBJValidationKeyPath) throws {
    try _invariant(at: keyPath)
    try SBJInvariantCheck.require(start <= end, at: keyPath, "invalid date range")
}

func sbjStructuralEquals(_ other: Self) -> Bool {
    _sbjStructuralEquals(other) && transientVersion == other.transientVersion
}
```

Put these overrides **inside the annotated type body**. A macro can only see members in the declaration it is attached to; adding the override later in an extension would collide with the already-generated forwarding member.

---

## Structural metadata

`SBJPropertyMetadata` is UI-independent metadata for one coded property.

```swift
let all = MealRecipe.sbjProperties
let servings = MealRecipe.propertyMetadata(for: \MealRecipe.servings)
let info = MealRecipe.propertyInfo(for: \MealRecipe.servings)
```

Each property metadata value contains:

- `sourceName` — Swift declaration name.
- `displayName` — default human-readable name.
- `keyPath` — actual model key path.
- `kind` — inferred structural category.
- `constraints` — model invariants.
- `hints` — non-invariant usage/presentation hints.
- `info` — optional documentation/accessibility metadata.
- structural comparison, validation, and empty-content operations bound to that property.

### Constraints are not hints

A constraint describes the model:

```swift
@SBJInteger(range: 1...24)
var servings: Int
```

A hint describes how a consumer may work with it:

```swift
@SBJString(.multiline)
var notes: String
```

For arrays, `minCount`, `maxCount`, and uniqueness are constraints; `reorderable` and `title` are usage/presentation information.

A consumer may ignore a hint. Ignoring a constraint does not make the underlying value structurally valid.

---

## Content semantics: `hasContent` is not `.isEmpty`

`HasContentCheckable` answers a domain-level question: does this value contain meaningful content?

That is deliberately not identical to collection count or optional presence.

SBJStructure supplies recursive behavior for common types:

- `String` / `Data` — content when nonempty.
- `Optional` — no content when `nil`; otherwise delegates when the wrapped value has content semantics.
- `Array` / `Set` — content when at least one element has content.
- `Dictionary` — content when it contains entries.
- generated `@SBJStructure` models — recursively compose their coded properties.

Generated models receive `_hasContent` and normally a forwarding `hasContent`.

`SBJContentCheck.containsEmptyContent(...)` recursively discovers empty content and lets callers mark application-defined types as traversal leaves.

This distinction is useful for generic editors, search filters, diagnostics, import analysis, and any other consumer that needs to distinguish "present" from "meaningful."

---

## Structural equality: `sbjStructuralEquals` is not `Equatable`

`Equatable` belongs to the type's normal Swift/business semantics. SBJStructure does not assume those semantics are identical to raw structural equality.

Generated models instead compare coded fields recursively:

```swift
let sameStoredStructure = edited.sbjStructuralEquals(original)
```

The generated implementation is conceptually:

```swift
func _sbjStructuralEquals(_ other: Self) -> Bool {
    SBJStructuralCompare.equals(name, other.name) &&
    SBJStructuralCompare.equals(servings, other.servings) &&
    SBJStructuralCompare.equals(ingredients, other.ingredients)
}
```

`SBJStructuralCompare` uses this order:

1. `SBJStructuralComparable` values — use structural comparison.
2. ordinary `Equatable` values — use `==`.
3. opaque `Encodable` values — compare a stable encoded representation.
4. description comparison only as a final fallback when no stronger structural operation exists.

`Optional`, `Array`, `Set`, and `Dictionary` implement recursive structural comparison so a large structured value does not normally require a whole-model JSON comparison.

This is also how the generic editor determines changed state: change is derived from current structure versus the original snapshot, not from mutation history. That means restoring a value to its original state removes the changed state naturally, and changes made through parent replacement, collection operations, custom bindings, or application code do not depend on a particular leaf setter having fired.

A model can override `sbjStructuralEquals(_:)` and still call `_sbjStructuralEquals(_:)` to reuse the generated field comparison.

---

## Explicit invariants: declaration and enforcement are separate

`@SBJStructure` generates recursive invariant checks from coded properties and annotation constraints.

```swift
do {
    try recipe.invariant(at: \MealRecipe.self)
} catch let error as SBJValidationError {
    print(error.keyPath)
    print(error.localizedDescription)
}
```

Nested paths retain useful structural locations including property key paths, array indices, dictionary keys, and set members.

Handwritten rules use the same public helpers:

```swift
try SBJInvariantCheck.require(
    startDate <= endDate,
    at: path,
    "start date must not be after end date"
)
```

Other helpers cover ranges, minimums, required optionals, text length, collection count, uniqueness, URL kinds, UUID nonzero requirements, and Data byte-count rules.

### Fail fast, collect, probe, or ignore

Validation policy belongs to the caller:

```swift
// Boundary/API save path
try value.invariant(at: .root)

// Development-only assertion-like probe
try value.debugInvariant()

// Reporting path
let issues = SBJStructureDiagnostics.issues(for: value)
```

The generic editor intentionally permits invariant-invalid but type-representable values. It withholds mutation only when the user's input cannot be represented by the property's Swift type at all.

### Declaration diagnostics are different from model validation

Some errors are knowable at compile time and should never become runtime validation:

- an annotation on an incompatible type;
- negative text/collection/Data limits;
- minimum greater than maximum;
- non-positive Data modulo;
- conflicting uniqueness declarations.

The macro diagnoses those declarations during compilation. A *well-formed* rule can still be violated by a runtime value, and that violation is reported only when a consumer requests validation.

---

## Property documentation and accessibility

`SBJPropertyInfo` attaches documentation and accessibility semantics to a typed property key path rather than to a particular UI.

```swift
extension MealRecipe {
    static func propertyInfo<Value>(
        for keyPath: KeyPath<MealRecipe, Value>
    ) -> SBJPropertyInfo? {
        switch keyPath {
        case \MealRecipe.servings:
            return SBJPropertyInfo(
                title: "Servings",
                summary: "The number of portions the recipe is intended to make.",
                details: "The structural constraint is 1 through 24 servings.",
                accessibilityLabel: "Recipe servings",
                accessibilityHint: "Enter the number of portions this recipe makes"
            )
        default:
            return nil
        }
    }
}
```

`SBJPropertyInfo` includes:

- `title`
- `summary`
- `details`
- `accessibilityLabel`
- `accessibilityHint`
- `accessibilityValue`

The lower-level `Accessible` protocol and `AccessibleItem` type are also UI-independent. SwiftUI adapters consume the same semantics, but other UI frameworks or documentation tools can do so as well.

This keeps property documentation DRY: the model declares what the property means once; each consumer chooses how to present it.

---

## Default creation and atomic initialization

Generic tooling sometimes needs to create a value without application context—for example when adding a collection element, enabling a nil optional, or creating an associated-enum payload.

`SBJStructured` therefore exposes:

```swift
static func sbjDefaultValue() -> Self?
```

The protocol default is `nil`. `@SBJStructure` synthesizes `.init()` when the macro can prove zero-argument construction is valid: either an explicit non-failable/non-throwing initializer defaults every parameter, or a struct with no explicit initializer has defaults for every stored property.

```swift
@SBJStructure
struct Note: Codable {
    var title = ""
    var body = ""
}
```

This does **not** mean the model must expose a builder-like lifecycle. It is a context-free construction capability for structural consumers.

If construction requires domain context, leave `sbjDefaultValue()` as `nil`, implement it explicitly, or register a creator with `SBJEditorRegistry`.

For the narrower case where a new collection element depends on existing elements, use `SBJCollectionElementCreatable`:

```swift
extension RecipeIngredient: SBJCollectionElementCreatable {
    static func sbjCreateValue(existing: [Self]) -> Self? {
        let usedNames = Set(existing.map(\.name))
        let base = "New ingredient"
        guard usedNames.contains(base) else { return RecipeIngredient(name: base) }

        let suffix = (2...).first { !usedNames.contains("\(base) \($0)") }!
        return RecipeIngredient(name: "\(base) \(suffix)")
    }
}
```

---

## Swift source export and designated initialization

`SBJSwiftEncoder` exports values as reconstructable Swift expressions using structural metadata.

```swift
let encoder = SBJSwiftEncoder()
let source = encoder.encode(recipe, named: "sample recipe")
```

Common Foundation/scalar values, optionals, collections, tuples, enums, and nested `SBJStructured` values have dedicated rendering. Set and dictionary output is deterministic.

### `@SBJDesignatedInit`

By default, structured export uses coded property order and matching property labels. When reconstruction should use the type's intentional construction API, mark that initializer:

```swift
@SBJStructure
struct FontSpec: Codable {
    var name: String?
    var size: Double

    @SBJDesignatedInit
    init(_ name: String? = nil, ofSize size: Double = 12) {
        self.name = name
        self.size = size
    }
}
```

The macro records initializer argument order, external labels, direct property mapping, and source-level default expressions. Export can then omit arguments whose values match those defaults.

This reinforces the preference for atomic construction: source export reconstructs the value through a meaningful initializer rather than simulating a builder by assigning properties one by one.

---

## Diagnostics and issues

`SBJIssue<Kind>` is a UI-independent diagnostic container with:

- issue kind;
- structural/display path;
- type name;
- optional value description;
- stable `Hashable` identity.

`SBJIssue.removingRedundantIssues(from:)` reduces duplicate and ancestor reports of the same underlying failure, which is useful when independent recursive passes discover the same problem at different levels.

`SBJStructureDiagnostics` produces validation issues for structured values. `SBJEditorDiagnostics` layers editor-specific diagnostics on top of structural diagnostics.

Diagnostics are intentionally data, not presentation. A sheet in the stock editor is only one possible consumer.

---

# Generic SwiftUI editor

The editor is generated from the same structural declarations. It is intended to remain useful without becoming a second schema system.

## Hostable editor pieces

The current API separates editor content from search/filter controls and from scrolling/layout ownership:

```swift
@State private var editorState = SBJEditorViewState()

VStack(spacing: 0) {
    SBJEditorSearchView(
        value: recipe,
        state: $editorState,
        registry: registry
    )

    SBJEditorScrollView(state: $editorState) {
        SBJEditorView(
            value: $recipe,
            state: $editorState,
            registry: registry
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
```

The host still owns margins, toolbars, inspectors, sheets, and surrounding chrome. `SBJEditorScrollView` is the stock scrolling policy: it observes `SBJEditorViewState.navigationTarget`, lets the editor expand the target's ancestor disclosures, and scrolls the requested property into view. This is what lets the issue viewer's trailing chevron dismiss the sheet and jump directly to the affected property.

Clients with a specialized scrolling container may continue to host `SBJEditorView` directly. In that case they own the final scroll operation and can observe `SBJEditorViewState.navigationTarget`; the editor still uses the target to reveal collapsed ancestors. `SBJCodableEditor` / `SBJCodableEditorCore` use `SBJEditorScrollView` automatically.

For deeply nested, dynamically sized content, `SBJEditorScrollView` (or an equivalent `ScrollView`/stack host) is generally preferable to a list-backed `Form`, because the editor contains rows whose heights can change substantially during search, disclosure expansion, and issue navigation.

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

## Search and filtering

`SBJEditSearchCriteria` groups search/filter state so new criteria can be added without threading separate booleans throughout the recursive renderer.

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

# Annotation reference

## `@SBJStructure`

Attaches structural metadata generation to a `Codable` struct or enum.

For structs:

- coded stored properties become structural metadata;
- writable coded properties become generic editor fields;
- immutable coded properties remain structural but are not editable;
- writable computed properties remain outside the structure unless explicitly marked `@SBJEditorProperty`.

For enums, associated-value case metadata is generated for recursive editing and source export.

## `@SBJString`

Adds String length constraints and/or text presentation.

```swift
@SBJString(.singleLine, minLength: 1, maxLength: 40)
var name: String

@SBJString(.multiline, maxLength: 2_000)
var notes: String
```

Parameters:

- `.singleLine` / `.multiline`
- `minLength`
- `maxLength`

## `@SBJInteger`

Adds an integer closed-range or minimum constraint.

```swift
@SBJInteger(range: 1...24)
var servings: Int

@SBJInteger(min: 0)
var experience: Int
```

## `@SBJNumber`

Adds a floating-point closed-range or minimum constraint.

```swift
@SBJNumber(range: 0...1)
var opacity: Double

@SBJNumber(min: 0)
var scale: Double
```

Non-finite values fail generated range/minimum validation.

## `@SBJOptional`

Adds an optional presence requirement.

```swift
@SBJOptional(required: true)
var owner: Owner?
```

The requirement is checked only during explicit validation.

## `@SBJArray`

Adds array constraints and usage hints.

```swift
@SBJArray(
    reorderable: true,
    title: \RecipeIngredient.name,
    minCount: 1,
    maxCount: 10,
    uniqueBy: \RecipeIngredient.id
)
var ingredients: [RecipeIngredient]
```

Parameters:

- `reorderable` — whether a consumer may expose stored-order changes.
- `title` — element key path used for human-readable item presentation.
- `minCount`
- `maxCount`
- `unique` — requires Hashable elements to be unique.
- `uniqueBy` — uniqueness by a Hashable element key path and a natural stable identity source for editor collection items.

`unique` and `uniqueBy` are mutually exclusive. Arrays always preserve stored order; `reorderable` does not imply sorting.

## `@SBJSet`

Adds Set count constraints and item-title metadata.

```swift
@SBJSet(
    title: \Proficiency.name,
    minCount: 1,
    maxCount: 20
)
var proficiencies: Set<Proficiency>
```

Sets have no stored ordering, so the stock editor presents them deterministically rather than offering reordering.

## `@SBJDictionary`

Adds dictionary entry-count constraints.

```swift
@SBJDictionary(minCount: 0, maxCount: 20)
var modifiers: [String: Int]
```

The generic editor stages key renames and rejects collisions instead of overwriting another entry.

## `@SBJDate`

Adds a `Date` range invariant.

```swift
@SBJDate(range: earliestAllowed...latestAllowed)
var modified: Date
```

A plain `Date` already receives the built-in date editor. The range is validation metadata, not a `DatePicker` input restriction.

## `@SBJURL`

Adds broad URL-kind constraints.

```swift
@SBJURL(allowed: [.file])
var sourceFile: URL

@SBJURL(allowed: [.network])
var serviceURL: URL
```

`.file` accepts file URLs. `.network` accepts absolute non-file URLs with a scheme. Relative URLs belong to neither category.

A plain URL needs no annotation and still receives the built-in URL editor.

## `@SBJUUID`

Adds a nonzero UUID constraint.

```swift
@SBJUUID(nonzero: true)
var identifier: UUID
```

The stock editor accepts canonical, compact, and brace-wrapped UUID text, normalizes valid input, and provides UUID generation whether or not the annotation is present.

## `@SBJData`

Adds Data byte-count constraints.

```swift
@SBJData(min: 16, max: 64, modulo: 16)
var payload: Data
```

Parameters operate on bytes:

- `min`
- `max`
- `modulo`

The built-in editor presents Data as multiline hexadecimal and does not mutate the model while textual input is incomplete or invalid.

## `@SBJColor`

Adds usage information to `CodableColor`.

```swift
@SBJColor(alpha: false)
var accent: CodableColor
```

A plain `CodableColor` already uses the built-in color editor. `alpha: false` tells consumers to treat the value as RGB-only.

## `@SBJNotEditable`

Suppresses generic editor generation while retaining structural membership.

```swift
@SBJNotEditable
var generatedSummary: String
```

The property remains in `sbjProperties`, content inspection, structural comparison, and invariant validation.

## `@SBJEditorProperty`

Adds a writable computed property to generic editing **without** making it structural.

```swift
@SBJEditorProperty
var platedPhoto: PlatformImage? {
    get { imageStore.load(identifier) }
    set { imageStore.stage(newValue, id: identifier) }
}
```

Editor-only properties:

- appear in `sbjEditorFields`;
- do not appear in `sbjProperties`;
- do not participate automatically in generated content semantics, structural equality, or invariants;
- do not need to conform to `Codable`.

This distinction is intentional: editability and structure are separate concerns.

## `@SBJPresentation`

Adds editor-neutral presentation semantics to a structural property. Presentation metadata does not alter storage, Codable behavior, validation, or assignment semantics.

The current presentation option is font-family selection for an optional String, where `nil` represents the platform/system family:

```swift
@SBJPresentation(.fontFamily)
var family: String?
```

Presentation hints are not invariants and may be ignored by non-UI consumers.

## `@SBJDesignatedInit`

Marks the initializer used as the source-of-truth reconstruction path for Swift source export. See [Swift source export and designated initialization](#swift-source-export-and-designated-initialization).

---

# Unannotated built-in values

Unannotated coded values are the normal case. Built-in scalar editing currently includes:

- `String`
- `Bool`
- signed and unsigned fixed-width integers
- `Float`
- `Double`
- `CGFloat`
- `Decimal`
- `Date`
- `URL`
- `UUID`
- `Data`
- `CodableColor`

`CodableFont` is itself an `@SBJStructure` model and additionally receives specialized font-family editing. It stores family/system font choice, point size, weight, italic state, and width, and can realize cached or uncached platform fonts through `CodableFontCache`.

Known value types use their ordinary `Equatable` behavior as structural leaves where appropriate.

---

# Reusable value utilities

Operations used by the stock editor are public when they are useful independently of the editor.

## Hexadecimal Data

```swift
let text = data.sbjHexFormat(bytesPerRow: 16)
let parsed = try text.sbjHexData()
```

`Data` provides `sbjHexDescription`, `sbjHexFormat(...)`, and `isZero`. `String` provides throwing `sbjHexData()` and optional `sbjHexToData()` parsing.

## URL and UUID parsing

```swift
let url = " https://example.com ".sbjURL
let uuid = "550E8400E29B41D4A716446655440000".sbjUUID
```

These are the same parsing rules used by the stock scalar editors.

## Safe collection mutation

```swift
var names: Set = ["one", "two"]
names.sbjReplace("one", with: "three")

var values = ["one": 1, "two": 2]
values.sbjRenameKey("one", to: "three")
```

Both operations reject collisions and leave the collection unchanged on failure.

## Codable copying and encoded fallback comparison

```swift
let snapshot = edited.sbjCodableCopy()
let encodedDifference = edited.sbjEncodedIsDifferent(from: original)
```

`sbjCodableCopy()` is useful for independent snapshots. Encoded comparison remains available as a public utility and as the structural-comparison fallback for opaque Codable values, but generated SBJ structures normally use field-by-field structural comparison.

---

# Public API organization

SBJStructure favors APIs that are discoverable from the value they operate on. General operations on `Data`, `String`, collections, and Codable values are public `sbj`-prefixed extensions.

Namespace/service types remain where there is no natural primary receiver or where the operation represents a service family:

- `SBJInvariantCheck` — explicit invariant evaluation.
- `SBJContentCheck` — recursive content inspection.
- `SBJStructuralCompare` — generic structural-equivalence dispatch.
- `SBJStructureDiagnostics` — UI-independent model diagnostics.
- `SBJEditorDiagnostics` — editor-specific diagnostics.
- `SBJDefaultValue` — type-erased context-free creation.
- `SBJEditorRegistry` — application editor/creator overrides.
- `SBJSwiftEncoder` — Swift source reconstruction.

---

# What the framework intentionally does not do

SBJStructure does not:

- wrap annotated stored properties;
- validate on every assignment;
- force a throwing or failable initialization policy;
- treat `Equatable` as structural persistence equality for generated structures;
- treat `.isEmpty` as universal content semantics;
- require a parallel builder/schema declaration;
- require the generic editor to use the structural model;
- require a particular scrolling/container UI;
- make editor-only computed properties part of persistence automatically;
- turn validation constraints into input restrictions.

Those omissions are design decisions, not missing enforcement.

---

# Package requirements

The current package uses Swift tools 6.4 and declares:

- iOS 17+
- watchOS 10+

The SwiftUI editor is `@MainActor` where appropriate; structural metadata and model operations remain usable independently of SwiftUI.



## System accessibility appearances

The generated editor treats system accessibility appearance preferences as part of its presentation contract, not as application-specific polish. Its chrome uses semantic system colors and preserves meaning independently of color.

- **Increase Contrast** strengthens borders, focus rings, hierarchy cues, and validation outlines.
- **Differentiate Without Color** adds a non-color selection cue to the editor's Changed/Empty filters; row state already uses distinct pencil and dashed-rectangle symbols rather than color alone.
- **Reduce Transparency** removes translucent validation/header fills where they are not necessary and relies on opaque outlines and structural cues instead. Focus shadows are suppressed.
- **Light and Dark appearance** use semantic foreground/background styles rather than fixed RGB presentation colors.
- Color filters should not erase meaning because changed, empty, invalid, disclosure, and selection states have shape/symbol/border cues in addition to color.

The Recipe previews include variants for increased contrast, Differentiate Without Color, Reduce Transparency, and dark increased-contrast appearance so these behaviors can be checked while the structural example remains the same.


### Keyboard, focus, and accessibility navigation

The generated editor uses native SwiftUI controls so Full Keyboard Access, Tab/Shift-Tab traversal, menus, toggles, text fields, and buttons retain platform behavior. SBJStructure adds structural semantics around those controls:

- The interactive field control owns the property's accessibility label; the separate visual label is hidden from VoiceOver to avoid duplicate stops.
- Changed, no-content, and invalid state are folded into the control's spoken label when present.
- Plain disclosure headers are one semantic accessibility target with an Expanded/Collapsed value. The decorative disclosure glyph is hidden from VoiceOver in that case; promoted editable headers keep the disclosure control separately accessible.
- Collection remove and reorder actions have explicit labels and action hints.
- Stable `SBJEditorItemIdentifier` values continue to drive SwiftUI item identity while `SBJEditorIndexPath` represents current position, so reordering preserves the logical view/control identity whenever SwiftUI can preserve focus.
- Programmatic focus after creating optional values or collection elements continues to use `SBJEditorFocusRequest`; normal keyboard focus remains owned by the native control.

Menu-backed scalar editors use one compact presentation: the selected value followed by a small up/down chevron. This keeps prototype editors dense while preserving an explicit menu affordance and native keyboard/menu behavior.

Use macOS/iPadOS Full Keyboard Access, VoiceOver, Switch Control, and Accessibility Inspector as behavioral tests; these cannot be fully simulated by static SwiftUI previews.


### Accessibility and localization regression harness

The canonical sample model is also the framework's accessibility/localization regression surface. The automatic and standalone editor previews plus integration tests all exercise that one fixture rather than maintaining separate preview-only or test-only models.

The preview matrix covers default and dark appearance, large Dynamic Type, a narrow AX5 layout, French and German locales, Arabic right-to-left presentation, and a deliberately changed/empty/invalid model state. System settings that are read-only SwiftUI environment values on the supported target (including Increase Contrast, Differentiate Without Color, and Reduce Transparency) are verified through Xcode Environment Overrides / Accessibility Inspector.

`SBJAccessibilityLocalizationRegressionTests` protects the non-rendered semantic contract: spoken structural state, Item Identifier vs Index Path behavior, locale-aware number/date formatting, domain-informed sizing invariants, and locale-invariant technical representations.

For the complete release checklist, including VoiceOver, Full Keyboard Access, Switch Control, and Accessibility Inspector steps, see [`ACCESSIBILITY_REGRESSION.md`](ACCESSIBILITY_REGRESSION.md).

## Localization and presentation resource design

The shared presentation-resource direction for localization, text fitting, symbology/images, semantic color, accessibility, Structure metadata, UIVocabulary, SBJLayout integration, and vendor/document/server overrides is documented in [Localization and Presentation Resources](../LOCALIZATION_AND_PRESENTATION_RESOURCES.md).
