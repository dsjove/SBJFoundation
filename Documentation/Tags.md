# Tags

`Tags` contains the generic tag model contracts, SwiftData-backed tag collection,
Codable value representation, and reusable SwiftUI editing/display controls.

## Responsibilities

- `Tagging` defines the user-visible tag state and inverse user relationship.
- `TagUser` defines tag ownership/use from a domain model.
- `TagBag` abstracts a collection of available tags.
- `TagBagSwiftData` provides the standard SwiftData implementation and explicit
  reload support for CloudKit/remote-store changes.
- `TagCodableValue` serializes the stable tag value (`id`, `name`, `color`) without
  attempting to Codable-encode persistence relationships.
- `TagsListView`, `TagsControlView`, and `TagsEditSheet` provide generic SwiftUI UI.

Domain models remain in the client app. A client persisted tag model conforms to
`Tagging`; a client model that consumes tags conforms to `TagUser`.

## Persistence and CloudKit

Tag relationship teardown is explicit because synchronized SwiftData relationship
mutation and deletion ordering have historically required deterministic behavior.
`TagBagSwiftData` uses `CoreDataStorage` lifecycle helpers and exposes `reload()`
because its UI-stable cache cannot assume the first fetch remains authoritative
after CloudKit imports.

TODO(CoreDataStorage production compatibility): validate the generic tag lifecycle
against the remaining production CoreData/iCloud apps before making stronger
assumptions about relationship ownership, delete timing, or cache invalidation.

## Codable

Do not make a persistence model Codable merely to serialize tags. Use
`TagCodableValue` for the common value state and let the client archive any
app-specific relationships separately.

## Rendering

Printable/Core Graphics representation deliberately does not live here.
`SBJLayout`, which depends on SBJFoundation, supplies `TagRenderable` and the
`Tagging.renderable(isPrimary:)` convenience.
