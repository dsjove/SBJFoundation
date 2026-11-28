# Structural model guide

`SBJStructure` describes Swift structures and enums independently of any user interface. Apply `@SBJStructure` to a model to generate structural metadata and the supporting model capabilities.

```swift
import SBJStructure

@SBJStructure
struct MeasurementRecord: Codable {
    @SBJString(minLength: 1)
    var title: String
    var amount: Int

    init(title: String, amount: Int) {
        self.title = title
        self.amount = amount
    }
}
```

## Structural metadata

`SBJStructured.sbjProperties` provides unified stored and computed property descriptors. A descriptor has a stable Swift `sourceName`, human-facing `displayName`, key path, declared value type, storage, access, constraints, hints, kind, and property information. Inspection does not mutate a model or enforce its invariants automatically.

`SBJStructuralTraversal.definition(of:)` describes a type without an instance and includes immutable and computed properties. `schema(of:)` and `visitValues(in:_:)` operate on writable structures. `SBJMutableStructure` exposes writable-property capabilities for consumers that need mutation.

`SBJTraversalOptions` filters the canonical definition. Private and fileprivate properties and `@SBJExclude` declarations are not part of the published definition. `@SBJFieldPresentation(exclude: true)` is excluded by default from Editor and AI traversal and included by `.definition`. The caller may explicitly include presentation-excluded fields.

## Content, validation and comparison

`HasContentCheckable` describes meaningful content independently of collection emptiness. `SBJInvariantCheck` and validation key paths identify violations. Structural equality and changed-state checks compare current values with a baseline; they do not depend on observing setter calls. Referenced-content traversal locates resource identifiers in nested values.

## Search and filtering



## Default construction

`SBJStructured.sbjDefaultValue()` returns an optional context-free default. `SBJDefaultValue.value(for:)` provides defaults for supported ordinary values and structural types. A missing default is represented by `nil`, not by an arbitrary instance. Collection-aware creation is handled independently through `SBJCollectionElementCreatable`.

## Swift source reconstruction

`SBJSwiftEncoder` exports expressions for structured values. Source reconstruction selects a complete initializer when its parameters cover all stored properties, matching internal or external parameter names. `_` labels and Swift parameter defaults do not prevent matching. `@SBJDesignatedInit` resolves explicit initializer selection.

When no complete initializer is selected, a default-constructible structure whose complete stored definition is writable can use an immediately invoked closure with assignments. Other Codable structures use a JSON-decoding expression when encoding succeeds. The decoding expression requires Foundation at its call site. Callers that require compilable generated code must account for the selected representation, the referenced types, and any necessary imports. If no reconstruction path succeeds, the current API may emit a diagnostic comment instead of a valid expression.

## Presentation metadata

Presentation annotations express formatting and disclosure preferences as data. They do not create SwiftUI controls. The StructuredEditor consumer implements controls, bindings, navigation, disclosure, and mutation policies.

## More information

See [Annotations and values](AnnotationsAndValues.md), [Source organization](Organization.md), and [Swift source encoding](SwiftSourceEncoding.md).
