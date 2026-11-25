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
