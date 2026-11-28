/// Selects discoverable properties. Private and fileprivate declarations are never discoverable.
/// Options within each dimension are inclusive; dimensions combine restrictively.
public struct SBJTraversalOptions: OptionSet, Hashable, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let stored = Self(rawValue: 1 << 0)
    public static let computed = Self(rawValue: 1 << 1)
    public static let readOnly = Self(rawValue: 1 << 2)
    public static let readWrite = Self(rawValue: 1 << 3)
    public static let publicAccess = Self(rawValue: 1 << 4)
    public static let packageAccess = Self(rawValue: 1 << 5)
    public static let internalAccess = Self(rawValue: 1 << 6)
    public static let presentationExcluded = Self(rawValue: 1 << 7)
    public static let all: Self = [.stored, .computed, .readOnly, .readWrite, .publicAccess, .packageAccess, .internalAccess]
    public static let editor: Self = [.stored, .computed, .readWrite, .publicAccess, .packageAccess, .internalAccess]
    public static let definition: Self = [.all, .presentationExcluded]

    public func includes<Root: SBJStructured>(_ property: SBJPropertyMetadata<Root>) -> Bool {
        guard !property.isPresentationExcluded || contains(.presentationExcluded) else { return false }
        let storage: Self = property.storage == .stored ? .stored : .computed
        let access: Self = property.access == .readWrite ? .readWrite : .readOnly
        let visibility: Self = switch property.visibility {
        case .publicAccess: .publicAccess
        case .packageAccess: .packageAccess
        case .internalAccess: .internalAccess
        }
        return contains(storage) && contains(access) && contains(visibility)
    }
}
