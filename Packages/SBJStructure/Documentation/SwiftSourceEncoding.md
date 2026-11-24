# Swift source encoding

`SBJSwiftEncoder` exports values as Swift expressions and supports `encode(_:named:)` for named declarations.

## Reconstruction selection

1. A complete initializer may be selected from `@SBJStructure` metadata. Its parameters must match coded stored properties without duplicates; the encoder uses external argument labels in source output.
2. A default-constructible structure with writable coded properties may be emitted as an immediately invoked closure: initialize a mutable local, assign properties, and return the local.
3. A Codable value can be emitted as a Foundation JSON decoding expression with an embedded Base64 payload if encoding succeeds.
4. When reconstruction is unavailable, the current interface may return a diagnostic comment. This is not compilable Swift.

### Example: mutable structure

```swift
let example = {
    var value = Example()
    value.name = "Example"
    return value
}()
```

Initializer selection is a source-generation contract, not a proof that an initializer's body preserves every stored value. Consumers needing source fidelity should test representative values, compile their generated source, and compare reconstructed results. Default construction and collection-dependent `next` creation are separate concerns.

## Limitations

The current export API returns `String`, not `throws`. Codable fallback expresses the encoded Codable representation, which may differ from all stored state for types with custom coding implementations. Generated expressions need the corresponding types in scope and Foundation for JSON decoding.
