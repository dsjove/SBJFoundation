import Foundation

/// UI policy for an array, separate from its snapshot invariants.
public struct SBJArrayPresentationValue: Codable, Sendable, Equatable {
    public var insertable: Bool
    public var removable: Bool
    public var reorderable: Bool
    public init(insertable: Bool = true, removable: Bool = true, reorderable: Bool = true) {
        self.insertable = insertable
        self.removable = removable
        self.reorderable = reorderable
    }
}

/// Configures array editing controls; never changes the array or enforces rules.
/// `title` is a compiler-checked element key path used to label each row.
@attached(peer)
public macro SBJArrayPresentation(
    title: AnyKeyPath? = nil,
    insertable: Bool = true,
    removable: Bool = true,
    reorderable: Bool = true
) = #externalMacro(module: "SBJDataDefinitionMacros", type: "SBJArrayPresentationMacro")
