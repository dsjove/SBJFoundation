import Foundation
import Observation
import SwiftData
import SBJLocalization

@MainActor
@Observable
public final class TagBagSwiftData<F>: @MainActor TagBag
where F: TagBagFactory, F.Tag: PersistentModel {
	public typealias Tag = F.Tag
	public typealias Factory = F

	private let modelContext: ModelContext
	private let factory: Factory
	
	public private(set) var tags: [Tag] = []

	public var title: String { factory.title }

	public init(modelContext: ModelContext, factory: Factory) {
		self.modelContext = modelContext
		self.factory = factory
	}

	private func loadTagsIfNeeded() {
		guard tags.isEmpty else { return }
		reload()
	}

	/// Refreshes the cached tag list after CloudKit imports or other external
	/// changes. The tag bag intentionally owns a cache for UI stability, so it
	/// must not assume the first fetch remains authoritative forever.
	public func reload() {
		do {
			tags = try modelContext.fetch(FetchDescriptor<Tag>())
		} catch {
			(error as NSError).printAsNSError()
		}
	}
/*
	func ensureTag(_ name: String, _ color: CodableColor) throws {
		var descriptor = FetchDescriptor<Tag>(
			predicate: #Predicate { $0.name == name }
		)
		descriptor.fetchLimit = 1
		if let _ = try context.fetch(descriptor).first {
			return
		}
		let tag = Tag(name, color)
		context.insert(tag)
	}
*/
	public func tags(_ search: String) -> [Tag] {
		loadTagsIfNeeded()
		return tags.filter(search: search)
	}

	public func addNewTag(named name: String) -> Tag {
		loadTagsIfNeeded()
		if let existing = tags.first(where: {$0.name == name}) {
			return existing
		}
		let newTag = factory.createTag(named: name)
		tags.addIdentified(newTag)
		newTag.insertNow(modelContext)
		return newTag
	}

	public func deleteTags(_ toBeDeleted: [Tag]) {
		for tag in toBeDeleted {
			tags.removeIdentified(tag)
		}

		// Preserve the proven deferred-delete behavior from the original tag
		// implementation. `deleteNow()` owns teardown and deletion ordering.
		// TODO(CoreDataStorage strategy): Validate whether the remaining production
		// apps still require next-run-loop deletion before removing this deferral.
		DispatchQueue.main.async {
			for tag in toBeDeleted {
				tag.deleteNow()
			}
		}
	}
}
