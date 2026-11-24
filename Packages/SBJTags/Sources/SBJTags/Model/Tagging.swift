import Foundation
import SwiftData
import SwiftUI
import SBJLocalization
import SBJDocuments
import SBJUIVocabulary

public protocol Tagging:
	Identifiable,
	Predicated,
	CustomDebugStringConvertible,
	Comparable where ID: Comparable {
	
	var name: String { get set }
	var color: CodableColor { get set }

	var displayName: String { get }
}

public extension Tagging {
	static var nameNomenclature: SBJNomenclature {
		SBJNomenclature(
			title: "Tag Name",
			summary: "The user-visible name of the tag.",
			details: "Names identify tags in tag lists, search, and editors.",
			accessibilityLabel: "Tag name"
		)
	}

	static var colorNomenclature: SBJNomenclature {
		SBJNomenclature(
			title: "Tag Color",
			summary: "Color used to visually identify the tag.",
			details: "The tag label automatically chooses a contrasting foreground color.",
			accessibilityLabel: "Tag color",
			accessibilityHint: "Changes the tag color."
		)
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

/// A taggable entity. Both observable reference models (including SwiftData)
/// and value models may conform. For value models, edits must be applied through
/// a writable binding or an owning store so mutations are not lost.
public protocol TagUser: Identifiable {
	associatedtype Tag: Tagging & AnyObject & Observable

	func hasTag(_ tag: Tag) -> Bool
	var sortedTags: [Tag] { get }
	mutating func addTag(_ tag: Tag, makePrimary: Bool)
	mutating func removeTag(_ tag: Tag)

	var __tags: [Tag]? { get set }
	var __primaryTagID: Tag.ID? { get set }

	static func propertyNomenclature<Value>(for keyPath: KeyPath<Self, Value>) -> SBJNomenclature?
}

public extension TagUser {
	static func propertyNomenclature<Value>(for keyPath: KeyPath<Self, Value>) -> SBJNomenclature? {
		switch keyPath as AnyKeyPath {
		case \Self.__tags:
			return SBJNomenclature(
				title: "Tags",
				summary: "Tags assigned to this item.",
				details: "Toggling a tag adds or removes its relationship to the current item.",
				accessibilityLabel: "Assigned tag",
				accessibilityHint: "Assigns or removes this tag from the current item."
			)
		case \Self.__primaryTagID:
			return SBJNomenclature(
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

	func hasTag(_ tag: Tag) -> Bool {
		__tags?.containsIdentified(tag) ?? false
	}

	mutating func addTag(_ tag: Tag) {
		addTag(tag, makePrimary: false)
	}

	var sortedTags: [Tag] {
		__tags?.sorted() ?? []
	}

	mutating func addTag(_ tag: Tag, makePrimary: Bool = false) {
		if __tags == nil {
			__tags = []
		}
		__tags?.addIdentified(tag)
		if makePrimary || __primaryTagID == nil {
			__primaryTagID = tag.id
		}
	}

	mutating func togglePrimary(_ tag: Tag) {
		if self.isTagPrimary(tag) {
			__primaryTagID = nil
		} else {
			addTag(tag, makePrimary: true)
		}
	}

	mutating func removeTag(_ tag: Tag) {
		if __primaryTagID == tag.id {
			__primaryTagID = nil
		}
		__tags?.removeIdentified(tag)
	}
}

/// Reference-only tag definitions with inverse model relationships.
/// The stored relationship itself remains in each app's existing persistence model.
public protocol TaggingSwiftData: Tagging, AnyObject, Observable, Teardownable {
	associatedtype User: TagUser & AnyObject where User.Tag == Self
	var __users: [User]? { get set }
}

public extension TaggingSwiftData {
	/// Preserve the existing manual relationship cleanup / deleteNow contract.
	var tearDownDeletesSelf: Bool { false }

	var userCount: Int { __users?.count ?? 0 }

	func isSoleUserID(_ id: AnyHashable?) -> Bool {
		guard let users = __users, let id else { return true }
		if users.count == 1 { return AnyHashable(users[0].id) == id }
		return users.isEmpty
	}

	func _userRemoved(_ user: User) {
		__users?.removeIdentified(user)
		// Let SwiftData manage the soon-to-be-deleted user's relationship.
	}

	func _tearDownTagRelations() {
		guard let users = __users else { return }
		for user in users { user.removeTag(self) }
		// Let SwiftData manage this tag's inverse list.
	}
}

/// Reference-backed owners use nonmutating API calls while still allowing
/// value-backed TagUser models to use the same mutating operations.
public extension TagUser where Self: AnyObject, Tag: TaggingSwiftData, Tag.User == Self {
	func _tearDownTagRelations() {
		var owner = self
		owner.__primaryTagID = nil
		owner.__tags?.forEach { $0._userRemoved(self) }
	}

	func addTag(_ tag: Tag) {
		addTag(tag, makePrimary: false)
	}

	func addTag(_ tag: Tag, makePrimary: Bool = false) {
		var owner = self
		if owner.__tags == nil { owner.__tags = [] }
		owner.__tags?.addIdentified(tag)
		if makePrimary || owner.__primaryTagID == nil {
			owner.__primaryTagID = tag.id
		}
	}

	func togglePrimary(_ tag: Tag) {
		var owner = self
		if isTagPrimary(tag) {
			owner.__primaryTagID = nil
		} else {
			addTag(tag, makePrimary: true)
		}
	}

	func removeTag(_ tag: Tag) {
		var owner = self
		if owner.__primaryTagID == tag.id { owner.__primaryTagID = nil }
		owner.__tags?.removeIdentified(tag)
		// Let SwiftData update the tag's inverse relationship.
	}
}

public protocol TagBag: AnyObject, Observable {
	associatedtype Tag: Tagging & AnyObject & Observable
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
	associatedtype Tag: Tagging & AnyObject & Observable
	var title: String { get }
	func seedTags()
	func createTag(named: String) -> Tag
}

public extension TagBagFactory {
	var title: String { "Tags" }
	func seedTags() {}
}
