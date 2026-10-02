import Foundation

/// Codable value representation of the generic, user-visible portion of a tag.
///
/// Persistent tag models often cannot or should not conform directly to `Codable`
/// because their relationship graph belongs to the persistence layer. This value
/// type provides a stable representation for export, recovery, interchange, and
/// other serialization without coupling Codable to SwiftData relationships.
@SBJStructure
public struct TagCodableValue<ID: Codable & Equatable>: SBJFoundationType {
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

    public static func propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
        switch keyPath as AnyKeyPath {
        case \Self.name:
            return SBJPropertyInfo(
                title: "Tag Name",
                summary: "The exported user-visible tag name.",
                details: "This is the portable value representation of a tag's name.",
                accessibilityLabel: "Tag name"
            )
        case \Self.color:
            return SBJPropertyInfo(
                title: "Tag Color",
                summary: "The exported tag color.",
                details: "This is the portable value representation of a tag's color.",
                accessibilityLabel: "Tag color"
            )
        default:
            return nil
        }
    }
}

public extension Tagging where ID: Codable & Equatable {
    var codableValue: TagCodableValue<ID> {
        TagCodableValue(self)
    }
}
