import Foundation
import Testing
import Observation
import SBJUIVocabulary
@testable import SBJTags


// Local fixtures keep SBJTags tests independent of Jove's Movies app models.
@MainActor
@Observable
private final class TestTag: Tagging {
    let id: String
    var name: String
    var color: CodableColor = CodableColor(0.2, 0.4, 0.8)
    var __users: [TestTagAssignment]?

    init(name: String) {
        self.id = UUID().uuidString
        self.name = name
    }
    static func == (lhs: TestTag, rhs: TestTag) -> Bool { lhs.id == rhs.id }
    func tearDown() { _tearDownTagRelations() }
}

@MainActor
private struct TestTagAssignment: TagUser {
    let id = UUID()
    var __tags: [TestTag]?
    var __primaryTagID: String?
}

@Suite("Tag filter set semantics")
@MainActor
struct TagFilterTests {
    @Test func orderedRulesOverrideEachOther() {
        let a = TestTag(name: "A")
        let b = TestTag(name: "B")
        let filter = TagFilter<TestTag>(startAll: false, operations: [
            .init(tagID: a.id, add: true),
            .init(tagID: b.id, add: false),
            .init(tagID: b.id, add: true)
        ])
        #expect(filter.matches(tagIDs: Set([a.id, b.id])))
        #expect(filter.matches(tagIDs: Set([a.id])))
        #expect(!filter.matches(tagIDs: Set([b.id])))
        #expect(!filter.matches(tagIDs: Set<String>()))
    }

    @Test func missingTagsRemainVisibleAndPersisted() throws {
        let a = TestTag(name: "A")
        let missing = UUID().uuidString
        let filter = TagFilter<TestTag>(startAll: true, operations: [
            .init(tagID: a.id, add: false), .init(tagID: missing, add: true)
        ])
        #expect(filter.invalidTagIDs(availableTags: [a]) == Set([missing]))
        #expect(!filter.matches(tagIDs: Set([a.id])))
        let copied = try JSONDecoder().decode(TagFilter<TestTag>.self,
            from: JSONEncoder().encode(filter))
        #expect(copied == filter)
    }

    @Test func tagUserPredicateUsesTagRelationships() {
        let a = TestTag(name: "A")
        let b = TestTag(name: "B")
        var assignment = TestTagAssignment()
        assignment.addTag(a, makePrimary: true)
        let filter = TagFilter<TestTag>(startAll: false,
            operations: [.init(tagID: a.id, add: true),
                         .init(tagID: b.id, add: false)])
        #expect(assignment.matches(filter, availableTags: [a,b]))
    }
}
