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
