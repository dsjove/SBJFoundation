/// Optional creation hook for collection elements whose new value depends on
/// values already present (for example a keyed collection of ability scores).
///
/// This is model/collection behavior rather than editor behavior. The generic
/// editor is one consumer; applications may use the same factory elsewhere.
public protocol SBJCollectionElementCreatable {
    static func sbjCreateValue(existing: [Self]) -> Self?
}

public extension SBJCollectionElementCreatable {
    static func _sbjCreateValue(existing: [Any]) -> Any? {
        sbjCreateValue(existing: existing.compactMap { $0 as? Self })
    }
}


/// Reusable ordered candidate selection for finite, unique collection keys.
/// Consumers can use this from `sbjCreateValue(existing:)` and construct a new
/// element with the selected key. The key need not be the whole element.
public enum SBJUniqueCollectionCandidate {
    public static func next<Element, Key: Hashable>(
        from candidates: [Key],
        existing: [Element],
        by key: (Element) -> Key
    ) -> Key? {
        let occupied = Set(existing.map(key))
        return candidates.first { !occupied.contains($0) }
    }
}

/// For enum-like collections, conforming to `SBJCollectionElementCreatable`
/// chooses the first unused case automatically. More complex structs can
/// implement their own `sbjCreateValue(existing:)` using their unique key.
public extension SBJCollectionElementCreatable where Self: CaseIterable & Hashable {
    static func sbjCreateValue(existing: [Self]) -> Self? {
        let used = Set(existing)
        return allCases.first { !used.contains($0) }
    }
}

/// Shared creation rule for collection members. A collection-specific factory has
/// priority over context-free defaults; a factory's nil result is final (for
/// example, when all unique enum cases are already present).
public enum SBJCollectionElementCreation {
    public static func create<Element>(existing: [Element]) -> Element? {
        if let factory = Element.self as? any SBJCollectionElementCreatable.Type {
            return factory._sbjCreateValue(existing: existing.map { $0 as Any }) as? Element
        }
        return SBJDefaultValue.value(for: Element.self)
    }
}
