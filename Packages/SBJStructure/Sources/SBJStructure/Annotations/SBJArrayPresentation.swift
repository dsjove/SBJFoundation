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
@attached(peer)
public macro SBJArrayPresentation(
    insertable: Bool = true,
    removable: Bool = true,
    reorderable: Bool = true
) = #externalMacro(module: "SBJStructureMacros", type: "SBJArrayPresentationMacro")
