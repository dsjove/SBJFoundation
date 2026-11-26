import Foundation

/// Deterministic staged-change receipts, independent of Foundation Models.
public struct SBJFieldChangeSummary: Sendable, Equatable {
	public let field: String
	public let oldValue: String
	public let proposedValue: String

	public init(field: String, oldValue: String, proposedValue: String) {
		self.field = field
		self.oldValue = oldValue
		self.proposedValue = proposedValue
	}
}

public struct SBJStructuralChangeSummary: Sendable, Equatable {
	public let id: String
	public let changes: [SBJFieldChangeSummary]

	public init(id: String, changes: [SBJFieldChangeSummary]) {
		self.id = id
		self.changes = changes
	}
}
