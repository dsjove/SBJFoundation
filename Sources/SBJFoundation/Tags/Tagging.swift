import Foundation
import SBJDataDefinition
import SBJDocuments
import SwiftUI
import SwiftData
import SBJLocalization

public protocol Tagging:
	AnyObject,
	Observable,
	Identifiable,
	Teardownable,
	Predicated,
	CustomDebugStringConvertible,
	Comparable where ID: Comparable {
	
	var name: String { get set }
	var color: CodableColor { get set }

	var displayName: String { get }

	static func propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo?

	associatedtype User: TagUser where User.Tag == Self
	var __users: [User]? { get set }
}

public extension Tagging {
	static func propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
		switch keyPath as AnyKeyPath {
		case \Self.name:
			return SBJPropertyInfo(
				title: "Tag Name",
				summary: "The user-visible name of the tag.",
				details: "Names identify tags in tag lists, search, and editors.",
				accessibilityLabel: "Tag name"
			)
		case \Self.color:
			return SBJPropertyInfo(
				title: "Tag Color",
				summary: "Color used to visually identify the tag.",
				details: "The tag label automatically chooses a contrasting foreground color.",
				accessibilityLabel: "Tag color",
				accessibilityHint: "Changes the tag color."
			)
		default:
			return nil
		}
	}

	/// Tags use the migrated CoreDataStorage lifecycle: teardown prepares
	/// relationships and `deleteNow()` performs the persistent deletion.
	var tearDownDeletesSelf: Bool { false }

	var userCount: Int {
		__users?.count ?? 0
	}

	func isSoleUser(_ user: User?) -> Bool {
		if let __users, let user {
			if __users.count == 1 {
				return __users.first?.id == user.id
			}
			return __users.isEmpty == true
		}
		return true
	}

	func _userRemoved(_ user: User) {
		__users?.removeIdentified(user)
		//Let SwiftData manage the soon to be deleted user._tags
	}

	func _tearDownTagRelations() {
		guard let users = __users else { return }
		users.forEach { $0.removeTag(self) }
		//Let SwiftData manage this tag's __user list
	}
}

public extension Tagging {
	var displayName: String {
		name
	}

	static func < (lhs: Self, rhs: Self) -> Bool {
		let nameCompare = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
		if nameCompare != .orderedSame {
			return nameCompare == .orderedAscending
		}
		if lhs.color != rhs.color {
			return lhs.color < rhs.color
		}
		return lhs.id < rhs.id
	}

	func predicated(search: String) -> Bool {
		guard let query = search.querify else { return true }
		return name.predicated(search: query)
	}

	var debugDescription: String {
		"\(Self.self): \(name)\(self.color.debugDescription)"
	}
}

public extension Tagging {
	var foregroundColor: Color {
		self.color.isLight ? .black : .white
	}

	var backgroundColor: Color {
		self.color.swiftUIColor
	}

	@ViewBuilder
	func label(isPrimary: Bool = false) -> some View {
		Text(displayName)
			.font(.caption).bold()
			.padding(.horizontal, 8)
			.padding(.vertical, 4)
			.background(backgroundColor)
			.foregroundColor(foregroundColor)
			.cornerRadius(8)
			.overlay(
				RoundedRectangle(cornerRadius: 8)
					.stroke(isPrimary ? Color.black : Color.clear, lineWidth: 2)
			)
	}
}

public protocol TagUser: AnyObject, Identifiable {
	associatedtype Tag: Tagging where Tag.User == Self

	func hasTag(_ tag: Tag) -> Bool
	var sortedTags: [Tag] { get }
	func addTag(_ tag: Tag, makePrimary: Bool)
	func removeTag(_ tag: Tag)

	var __tags: [Tag]? { get set }
	var __primaryTagID: Tag.ID? { get set }

	static func propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo?
}

public extension TagUser {
	static func propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
		switch keyPath as AnyKeyPath {
		case \Self.__tags:
			return SBJPropertyInfo(
				title: "Tags",
				summary: "Tags assigned to this item.",
				details: "Toggling a tag adds or removes its relationship to the current item.",
				accessibilityLabel: "Assigned tag",
				accessibilityHint: "Assigns or removes this tag from the current item."
			)
		case \Self.__primaryTagID:
			return SBJPropertyInfo(
				title: "Primary Tag",
				summary: "Identifier of the item's primary tag.",
				details: "Selecting an already-primary tag clears the primary designation.",
				accessibilityLabel: "Primary tag",
				accessibilityHint: "Sets or removes this tag as the primary tag."
			)
		default:
			return nil
		}
	}

	var tagCount: Int {
		__tags?.count ?? 0
	}

	func isTagPrimary(_ tag: Tag) -> Bool {
		tag.id == __primaryTagID
	}

	var primeTag: Tag? {
		__tags?.findIdentified(__primaryTagID)
	}

	func _tearDownTagRelations() {
		__primaryTagID = nil
		__tags?.forEach { $0._userRemoved(self) }
	}

	func hasTag(_ tag: Tag) -> Bool {
		__tags?.containsIdentified(tag) ?? false
	}

	func addTag(_ tag: Tag) {
		addTag(tag, makePrimary: false)
	}

	var sortedTags: [Tag] {
		__tags?.sorted() ?? []
	}

	func addTag(_ tag: Tag, makePrimary: Bool = false) {
		if __tags == nil {
			__tags = []
		}
		__tags?.addIdentified(tag)
		if makePrimary || __primaryTagID == nil {
			__primaryTagID = tag.id
		}
	}

	func togglePrimary(_ tag: Tag) {
		if self.isTagPrimary(tag) {
			__primaryTagID = nil
		} else {
			addTag(tag, makePrimary: true)
		}
	}

	func removeTag(_ tag: Tag) {
		if __primaryTagID == tag.id {
			__primaryTagID = nil
		}
		__tags?.removeIdentified(tag)
		//Let SwiftData update the tag's __users.
	}
}

public protocol TagBag: AnyObject, Observable {
	associatedtype Tag: Tagging
	var title: String { get }
	func tags(_ search: String) -> [Tag]
	func addNewTag(named name: String) -> Tag
	func deleteTags(_ toBeDeleted: [Tag])
}

public extension TagBag {
	func addNewTag() -> Tag {
		addNewTag(named: "")
	}
}

public protocol TagBagFactory {
	associatedtype Tag: Tagging
	var title: String { get }
	func seedTags()
	func createTag(named: String) -> Tag
}

public extension TagBagFactory {
	var title: String { "Tags" }
	func seedTags() {}
}
