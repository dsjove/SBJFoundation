# SBJTags

`SBJTags` contains a reusable tagging model and tag-selection UI. It separates tag identity and user-visible metadata from persistence, and offers SwiftData-backed collections and SwiftUI controls where those are appropriate.

## Getting started

A portable representation of a tag can be encoded without serializing an entire persistence object graph:

```swift
import SBJTags
import SBJDataDefinition

let tag = TagCodableValue(
    id: UUID(),
    name: "Reference",
    color: CodableColor(0.2, 0.4, 0.8)
)
let data = try JSONEncoder().encode(tag)
```

For an application tag system, define models conforming to `Tagging`, connect owners through `TagUser`, and provide a `TagBag` to locate and manage tags. `TagBagSwiftData` supplies a SwiftData-backed option. `TagsListView`, `TagsControlView` and `TagsEditSheet` provide display and editing UI; their generic parameters preserve your app's tag types.

