import Foundation

/// Editor controls for sets; these settings never enforce collection rules.
public struct SBJSetPresentationValue: Codable, Sendable, Equatable {
    public var insertable: Bool
    public var removable: Bool
    public var sort: SBJSortDirection?
    public init(insertable: Bool = true, removable: Bool = true, sort: SBJSortDirection? = nil) {
        self.insertable = insertable
        self.removable = removable
        self.sort = sort
    }
}

/// An optional key path selecting display titles for elements in a set.
@attached(peer)
public macro SBJSetPresentation(title: AnyKeyPath? = nil, insertable: Bool = true, removable: Bool = true, sort: SBJSortDirection? = nil) = #externalMacro(module: "SBJDataDefinitionMacros", type: "SBJSetPresentationMacro")
