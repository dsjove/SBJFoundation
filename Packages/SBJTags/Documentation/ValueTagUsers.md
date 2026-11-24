# Value-type TagUser support

`TagUser` is no longer restricted to classes. Mutating default methods support both
SwiftData classes and ordinary structs. Existing `TagsEditSheet(tagBag:user:)`
remains for reference models; `TagsEditSheet(tagBag:user: $value)` writes changes
back to a bound struct. The editor calls the default tag methods rather than
mutating copies of the user.

## Relationship semantics

`Tagging.__users` is still the existing inverse relationship API for SwiftData
models. SwiftData is responsible for maintaining inverse relationships.
Value-type users are not live inverse object relationships. `_tearDownTagRelations`
will not mutate copied value-type users. Clients using value-type users must own
any usage index and cleanup themselves.

## Compatibility

- Existing SwiftData models: no conformance changes expected.
- Existing class-based `TagsEditSheet` call sites: unchanged.
- Existing tag-bag storage / deferred deletion: unchanged.
- Source compatibility should be verified against actual SwiftData client apps.
- The macOS/iOS package cannot be fully built in a Linux environment.
