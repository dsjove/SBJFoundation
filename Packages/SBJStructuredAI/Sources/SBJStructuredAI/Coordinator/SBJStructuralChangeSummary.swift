import Foundation

/// Deterministic staged-change receipts, independent of Foundation Models.
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

/// An applied structural change receipt; full change details are in the proposal summary.
public struct SBJAIChangeResult: Sendable, Equatable {
    public let field: String
    public let previousValue: String
    public let currentValue: String

    public init(field: String, previousValue: String, currentValue: String) {
        self.field = field
        self.previousValue = previousValue
        self.currentValue = currentValue
    }
}

