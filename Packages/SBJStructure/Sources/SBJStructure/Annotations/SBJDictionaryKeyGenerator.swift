/// Type-erased dictionary insertion policy carried by property metadata.
/// The factory binds the generator to the actual declared dictionary type.
public struct SBJDictionaryKeyGenerator {
    private let generate: (Any, Any) -> Any?

    public init<Root, Key: Hashable, Value>(
        for keyPath: KeyPath<Root, [Key: Value]>,
        _ generator: @escaping ([Key: Value], Value) -> Key?
    ) {
        generate = { dictionary, value in
            guard let dictionary = dictionary as? [Key: Value],
                  let value = value as? Value else { return nil }
            return generator(dictionary, value).map { $0 as Any }
        }
    }

    public init<Root, Key: Hashable, Value>(
        for keyPath: KeyPath<Root, [Key: Value]?>,
        _ generator: @escaping ([Key: Value], Value) -> Key?
    ) {
        generate = { dictionary, value in
            guard let dictionary = dictionary as? [Key: Value],
                  let value = value as? Value else { return nil }
            return generator(dictionary, value).map { $0 as Any }
        }
    }

    public func key<Key: Hashable, Value>(for dictionary: [Key: Value], value: Value) -> Key? {
        generate(dictionary, value) as? Key
    }
}
