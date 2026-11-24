# SBJTags

`SBJTags` provides reusable tag assignment, ordered tag filtering, optional SwiftData tag collections, SwiftUI editing, and printable tag rendering. Applications define their own tag and owner models; the library does not own an application's persistence schema.

## Choose the appropriate API

| Client task | API |
| --- | --- |
| Describe a tag with an identity, name and color | `Tagging` |
| Assign tags and distinguish the primary tag | `TagUser` |
| Evaluate an ordered include/exclude filter | `TagFilter<Tag>` |
| Encode a tag's portable value without SwiftData relationships | `TagCodableValue<ID>` / `tag.codableValue` |
| Provide, create, and delete available tag definitions | `TagBag` / `TagBagFactory` |
| Back the tag bag with a SwiftData `ModelContext` | `TagBagSwiftData` |
| Edit assignments and tag definitions in SwiftUI | `TagsEditSheet`, `TagsControlView`, `TagsListView` |
| Edit a filter in SwiftUI | `TagFilterEditor` |
| Print/render tag chips through SBJLayout | `JCSTag`, `JCSTagGroup`, `renderableTags()` |

## Tag models and assignments

A tag type conforms to `Tagging`, providing an `Identifiable` ID, mutable `name`, and `CodableColor`. `TagUser` represents a tag owner and supplies `__tags` and `__primaryTagID` storage as well as assignment operations. `TagUser.Tag` must be an observable reference type, even when the owner itself is a value type. For value-type owners, use the `TagsEditSheet(tagBag:user:onDone:)` initializer that accepts `Binding<T>` so edits write back to the owner. For reference models, use the existing `user: T?` initializer.

The first added tag becomes primary by default. Additional tags do not replace the primary unless requested. Toggling an already-primary tag clears only the primary designation, not the assignment; removing a primary tag also clears that designation. Clients persist their own tag relationships.

## Ordered filters

`TagFilter` starts with everything (`startAll: true`) or nothing and applies matching operations in order; **the last matching rule wins**. A criterion can identify a particular tag ID or require at least one matching available tag (`.hasTag`). Missing tag identifiers remain in filter data for editing and round-tripping, but an unresolved ID does not match when evaluating a `TagUser` through `availableTags`.

The `TagFilterEditor` takes a binding to the filter. Changes update the binding; its optional `onChange` callback lets the application save. The editor's Done action does not independently persist data. Existing encoded named-tag rules retain their on-disk `tagID`/`add` representation. Legacy `hasNoTag` rules are translated on decoding to equivalent modern filter operations.

## SwiftData and synchronization

`TagBagSwiftData` works with an application-supplied `ModelContext` and `TagBagFactory`. It caches the fetched tags for UI stability. The first search loads its cache, including an empty result; `reload()` explicitly refreshes it after CloudKit imports, external saves, or other changes. Failed fetches report the error and can be retried if no successful load occurred. `addNewTag(named:)` reuses an exactly matching cached name; clients can normalize names at their own boundary if needed.

Deletion remains **deferred to the next main-queue turn**, honoring the existing `deleteNow()`/relationship teardown contract. Applications integrating SwiftData and CloudKit should verify their actual store/model deletion behavior and call `reload()` after remote changes. The tag bag does not perform automatic remote-change observation or guarantee persistence by itself.

## Codable and reporting

```swift
import SBJTags
import SBJStructure

let tag = TagCodableValue(
    id: UUID(),
    name: "Reference",
    color: CodableColor(0.2, 0.4, 0.8)
)
let archive = try JSONEncoder().encode(tag)
```

`TagCodableValue` contains only the portable value fields: ID, name and color. It does not serialize SwiftData inverse relationships. Printable tag chips are implemented with `SBJLayout`'s generic rendering primitives, while SwiftUI labels use the tag's semantic color and display name.

See [Documentation/Tags.md](Documentation/Tags.md) for persistence and presentation boundaries.
