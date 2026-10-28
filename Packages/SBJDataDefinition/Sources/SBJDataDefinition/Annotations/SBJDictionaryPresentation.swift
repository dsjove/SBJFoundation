import Foundation

/// Field presentation for dictionary keys and values, independent of validation.
public enum SBJDictionarySortBy: String, Codable, Sendable, Equatable {
    case key
    case value
}

public struct SBJDictionaryPresentationValue: Codable, Sendable, Equatable {
    public var insertable: Bool
    public var removable: Bool
    public var sort: SBJSortDirection?
    public var sortBy: SBJDictionarySortBy
    public var key: SBJFieldPresentationValue?
    public var value: SBJFieldPresentationValue?

    public init(key: SBJFieldPresentationValue? = nil, value: SBJFieldPresentationValue? = nil, insertable: Bool = true, removable: Bool = true, sort: SBJSortDirection? = nil, sortBy: SBJDictionarySortBy = .key) {
        self.insertable = insertable
        self.removable = removable
        self.sort = sort
        self.sortBy = sortBy
        self.key = key
        self.value = value
    }
}

/// Explicit key/value presentation without a separate annotation per value type.
@attached(peer)
public macro SBJDictionaryPresentation(
    key: SBJFieldPresentationValue? = nil,
    value: SBJFieldPresentationValue? = nil,
    insertable: Bool = true,
    removable: Bool = true,
    sort: SBJSortDirection? = nil,
    sortBy: SBJDictionarySortBy = .key
) = #externalMacro(module: "SBJDataDefinitionMacros", type: "SBJDictionaryPresentationMacro")
