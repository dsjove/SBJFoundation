/// Type-level inspection of standard Swift containers without constructing a value.
/// Child types are ordered as wrapped value, element, or dictionary key then value.
public enum SBJStructuralType {
    public enum Container {
        case optional(Any.Type)
        case array(Any.Type)
        case set(Any.Type)
        case dictionary(key: Any.Type, value: Any.Type)

        public var childTypes: [Any.Type] {
            switch self {
            case .optional(let type), .array(let type), .set(let type): [type]
            case .dictionary(let key, let value): [key, value]
            }
        }
    }

    public static func container(of type: Any.Type) -> Container? {
        (type as? any SBJStructuralContainerType.Type)?.sbjContainer
    }
}

private protocol SBJStructuralContainerType {
    static var sbjContainer: SBJStructuralType.Container { get }
}

extension Optional: SBJStructuralContainerType {
    fileprivate static var sbjContainer: SBJStructuralType.Container { .optional(Wrapped.self) }
}
extension Array: SBJStructuralContainerType {
    fileprivate static var sbjContainer: SBJStructuralType.Container { .array(Element.self) }
}
extension Set: SBJStructuralContainerType {
    fileprivate static var sbjContainer: SBJStructuralType.Container { .set(Element.self) }
}
extension Dictionary: SBJStructuralContainerType {
    fileprivate static var sbjContainer: SBJStructuralType.Container { .dictionary(key: Key.self, value: Value.self) }
}

/// Runtime presence, separate from content and structural validity.
public enum SBJOptionalPresence: Equatable {
    case notOptional, notSet, set

    public var count: Int? {
        switch self {
        case .notOptional: nil
        case .notSet: 0
        case .set: 1
        }
    }
}

private protocol SBJOptionalPresenceProviding {
    var sbjOptionalPresence: SBJOptionalPresence { get }
}

extension Optional: SBJOptionalPresenceProviding {
    fileprivate var sbjOptionalPresence: SBJOptionalPresence {
        switch self {
        case .none: .notSet
        case .some: .set
        }
    }
}

public extension SBJStructuralType {
    static func optionalPresence(of value: Any) -> SBJOptionalPresence {
        (value as? any SBJOptionalPresenceProviding)?.sbjOptionalPresence ?? .notOptional
    }
}
