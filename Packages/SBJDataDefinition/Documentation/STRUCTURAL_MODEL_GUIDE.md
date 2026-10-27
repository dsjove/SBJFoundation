# Structural model guide

`SBJDataDefinition` describes Codable structures and enums independently of any user interface. Apply `@SBJStructure` to a model to generate structural metadata and the supporting model capabilities.

```swift
import SBJDataDefinition

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

`SBJStructured.sbjProperties` provides coded stored-property descriptors. A descriptor has a stable Swift `sourceName`, human-facing `displayName`, key path, kind, constraints, hints, and property information. Inspection does not mutate a model or enforce its invariants automatically.

`SBJStructuralTraversal.definition(of:)` describes a type without an instance and includes immutable properties. `schema(of:)` and `visitValues(in:_:)` operate on writable structures. `SBJMutableStructure` exposes writable-property capabilities for consumers that need mutation.

## Content, validation and comparison

`HasContentCheckable` describes meaningful content independently of collection emptiness. `SBJInvariantCheck` and validation key paths identify violations. Structural equality and changed-state checks compare current values with a baseline; they do not depend on observing setter calls. Referenced-content traversal locates resource identifiers in nested values.

## Search and filtering

`SBJStructuralSearchMatcher` searches structured values. `SBJStructuralSearchAtomic` marks types whose meaningful textual representation should be searched without recursive reflection. `SBJStructuralSearchCriteria` combines text queries with changed-only and empty-content filters. Text matching delegates to SBJLocalization. Search results are independent of any view's disclosure state.

## Default construction

`SBJStructured.sbjDefaultValue()` returns an optional context-free default. `SBJDefaultValue.value(for:)` provides defaults for supported ordinary values and structural types. A missing default is represented by `nil`, not by an arbitrary instance. Collection-aware creation is handled independently through `SBJCollectionElementCreatable`.

## Swift source reconstruction

`SBJSwiftEncoder` exports expressions for structured values. Source reconstruction selects a complete initializer when its parameters cover the coded properties, matching internal or external parameter names. `_` labels and Swift parameter defaults do not prevent matching. `@SBJDesignatedInit` resolves explicit initializer selection.

When no complete initializer is selected, a default-constructible structure whose coded properties are writable can use an immediately invoked closure with assignments. Other Codable structures use a JSON-decoding expression when encoding succeeds. The decoding expression requires Foundation at its call site. Callers that require compilable generated code must account for the selected representation, the referenced types, and any necessary imports. If no reconstruction path succeeds, the current API may emit a diagnostic comment instead of a valid expression.

## Presentation metadata

Presentation annotations express formatting and disclosure preferences as data. They do not create SwiftUI controls. The StructuredEditor consumer implements controls, bindings, navigation, disclosure, and mutation policies.

## More information

See [Annotations and values](ANNOTATIONS_AND_VALUES.md), [Source organization](ORGANIZATION.md), and [Swift source encoding](SWIFT_SOURCE_ENCODING.md).
