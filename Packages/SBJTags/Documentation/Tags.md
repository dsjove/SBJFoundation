# SBJTags — client contracts and integration boundaries

## Model

`Tagging` defines a tag's stable ID, mutable name, color, searchable name, display name, and comparison. Sorting is case-insensitive by name, then by color, then by ID. The default `TagUser` implementation manages assignment and primary-tag selection; application models own storage and persistence. `TaggingSwiftData` provides the optional inverse-reference/teardown integration for reference models.

`TagUser` supports value owners as well as observable reference owners. Bind value owners to `TagsEditSheet` using `Binding<T>`; changing a copied value without writing it back to its owner will not persist the edit.

## Filtering

A `TagFilter<Tag>` is an ordered include/exclude expression over available tag IDs. Matching rules override earlier matches, while nonmatching rules leave the current result unchanged. `hasTag` matches nonempty assignments **among the available tag definitions supplied for evaluation**. Keep the `availableTags` list sufficiently up-to-date for correct results, including after CloudKit imports. Missing tag IDs are retained, reported by `invalidTagIDs`, and can be corrected in the editor. Encoding retains the existing data shape, and decoding migrates legacy `hasNoTag` conditions.

## Persistence

`TagBagSwiftData` fetches lazily and caches even an empty successful result. Applications explicitly call `reload()` after external changes. Failure to fetch leaves the previous cache available; a failed initial fetch can be retried. Deletion uses deferred `deleteNow()` to preserve the existing relationship teardown contract. This remains a persistence integration point that should be verified in each production application; do not assume CloudKit synchronization itself updates the bag cache.

## Presentation and rendering

Tag screens and controls are in `Presentation`. Printing-oriented tag chips are in `Rendering` and use `SBJLayout`. Both represent the same `Tagging` values, but neither controls data persistence. Help assets are package resources.

## Future design

Consider an explicit persistence error/reporting interface for applications that need to display fetch failures. Any change to deferred deletion should first be validated against the production SwiftData/CloudKit models. Those are future considerations, not current guarantees.
