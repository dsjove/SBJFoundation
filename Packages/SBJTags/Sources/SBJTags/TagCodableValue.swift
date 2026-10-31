import Foundation
import SBJDataDefinition
import SBJUIVocabulary

/// Codable value representation of the generic, user-visible portion of a tag.
///
/// Persistent tag models often cannot or should not conform directly to `Codable`
/// because their relationship graph belongs to the persistence layer. This value
/// type provides a stable representation for export, recovery, interchange, and
/// other serialization without coupling Codable to SwiftData relationships.
@SBJStructure
public struct TagCodableValue<ID: Codable & Equatable>: Codable, Equatable, SBJTextPresentable {
	public var id: ID
	public var name: String
	public var color: CodableColor

	public init(id: ID, name: String, color: CodableColor) {
		self.id = id
		self.name = name
		self.color = color
	}

	public init<Tag: Tagging>(_ tag: Tag) where Tag.ID == ID {
		self.init(id: tag.id, name: tag.name, color: tag.color)
	}

	public var presentedValue: String { name }

	public static var nameInfo: SBJPropertyInfo { .init(
		title: "Tag Name",
		summary: "The exported user-visible tag name.",
		details: "This is the portable value representation of a tag's name.",
		accessibilityLabel: "Tag name"
	)}

	public static var colorInfo: SBJPropertyInfo { .init(
		title: "Tag Color",
		summary: "The exported tag color.",
		details: "This is the portable value representation of a tag's color.",
		accessibilityLabel: "Tag color"
	)}
}

public extension Tagging where ID: Codable & Equatable {
	var codableValue: TagCodableValue<ID> {
		TagCodableValue(self)
	}
}
