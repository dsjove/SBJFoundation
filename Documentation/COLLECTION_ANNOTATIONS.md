# Collection annotations

DataDefinition **rules** describe the validity of a snapshot. They are only checked when the client explicitly invokes an invariant; they never enforce mutations, repair data, or sort collections. **Presentation** annotations describe the UI offered by an editor. **PropertyInfo** is end-user descriptive metadata.

## Arrays

`@SBJArray(minCount:maxCount:unique:uniqueBy:sorted:)` describes collection-level constraints. `sorted: .ascending` and `.descending` use element `Comparable` order, scanning adjacent pairs and reporting the first out-of-order index without sorting or changing values. `uniqueBy` uses a typed Swift key path. Insertion is a mutation, not an invariant.

`@SBJArrayPresentation(title:insertable:removable:reorderable:)` describes editor capabilities; each capability defaults to `true`. `title` is a typed element key path. A UI that suppresses an action does not prohibit the mutation in application code.

## Sets

`@SBJSet(minCount:maxCount:)` describes cardinality. Sets already guarantee uniqueness under `Hashable`/`Equatable`; their storage has no positional order.

`@SBJSetPresentation(title:insertable:removable:sort:)` controls editor capabilities and optional display sorting. `sort: nil` leaves display order unspecified; `.ascending` or `.descending` uses `Comparable` element semantics via constrained sorting helpers. Sorting a presentation must not mutate the underlying Set.

## Dictionaries

`@SBJDictionary(minCount:maxCount:key:value:)` describes count and optional member constraints. `key:` and `value:` take literal arrays of existing supported rule configurations, combined with AND semantics. Macro-generated invariant calls are type-checked against the actual key and value types; incompatible rule types are compilation failures. Invariants report failures only when invoked. Structural metadata preserves each configured rule as `.dictionaryKeyRule(...)` or `.dictionaryValueRule(...)`.

`@SBJDictionaryPresentation(key:value:insertable:removable:sort:sortBy:)` accepts optional `SBJFieldPresentationValue` instances for key and value labeling and visibility. Sorting is optional (`sort: nil`), with `sortBy: .key` by default; for value sorting, matching values are ordered by key in the same direction. Constrained sorting helpers require comparable types as appropriate. Dictionary storage is not changed.

**Current integration limit:** presentation sorting helpers and configuration metadata exist, but automatically sorted StructuredEditor rows and annotation-generated `Comparable` diagnostics for Set/Dictionary presentation are not yet established. Do not rely on the annotation alone to sort editor rows or diagnose unsupported element types until that integration is implemented and verified.

## Field presentation for collection members

For Array and Set properties, the **first** `@SBJFieldPresentation` configures the collection; the **second** configures its elements. The element value provides `name`, `exclude`, and `autoExpand`: hiding rows does not remove elements, and initial expansion remains user-controllable.

For Dictionary use the explicit `key:` and `value:` fields of `@SBJDictionaryPresentation` rather than positional annotations. Excluding a key label does not hide the associated value; excluding a value presentation hides its editor row without deleting dictionary contents.

## Design principles

Where suitable, reusable collection operations live on constrained Swift collection extensions. Key paths remain typed in code; serialization is not a reason to replace them with string identifiers. No collection presentation setting enforces a domain rule.
