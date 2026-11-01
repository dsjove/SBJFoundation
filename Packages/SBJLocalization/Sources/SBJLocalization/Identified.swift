import Foundation

public struct Identified<T>: Identifiable, Hashable {
	public let id: UUID
	public let value: T

	public init(_ value: T, id: UUID = UUID()) {
		self.id = id
		self.value = value
	}

	public static func == (lhs: Self, rhs: Self) -> Bool {
		lhs.id == rhs.id
	}

	public func hash(into hasher: inout Hasher) {
		id.hash(into: &hasher)
	}
}
