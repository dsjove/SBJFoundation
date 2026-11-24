import Foundation

/// Existing event cases are retained so application coordinators can keep
/// their exhaustive switch statements while the implementation is absent.
public enum SBJAIConversationEvent: Sendable, Equatable {
    case text(String)
    case fieldsRead([String])
    case resolvedFieldsRead([SBJAIFieldReadSummary])
    case fieldListRead(totalMatches: Int, fields: [SBJAIFieldReadSummary])
    case approvalRequested(SBJAIChangeSummary)
    case toolFailure(name: String, message: String)
}

public struct SBJAIFieldReadSummary: Sendable, Equatable {
    public let hierarchy: [String]
    public let field: String
    public let value: String
    public let collectionElement: String?

    public init(hierarchy: [String], field: String, value: String, collectionElement: String? = nil) {
        self.hierarchy = hierarchy
        self.field = field
        self.value = value
        self.collectionElement = collectionElement
    }

    public var resolvedPath: String { hierarchy.joined(separator: " / ") }
    public var conciseAnswer: String {
        if let collectionElement { return "\(collectionElement)'s \(field): \(value)" }
        return "\(field): \(value)"
    }
}

public struct SBJAIFieldChangeSummary: Sendable, Equatable {
    public let field: String
    public let oldValue: String
    public let proposedValue: String

    public init(field: String, oldValue: String, proposedValue: String) {
        self.field = field
        self.oldValue = oldValue
        self.proposedValue = proposedValue
    }
}

public struct SBJAIChangeSummary: Sendable, Equatable {
    public let id: String
    public let changes: [SBJAIFieldChangeSummary]

    public init(id: String, changes: [SBJAIFieldChangeSummary]) {
        self.id = id
        self.changes = changes
    }
}

/// Placeholder return type; no change results are constructed in this package.
public struct SBJAIChangeResult: Sendable, Equatable {
    public init() {}
}

public enum SBJAIConversationError: Error, LocalizedError, Equatable {
    case emptyMessage
    case unknownProposal

    public var errorDescription: String? {
        switch self {
        case .emptyMessage: "Enter a message first."
        case .unknownProposal: "No change proposal exists in this stub." 
        }
    }
}
