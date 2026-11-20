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

    init(name: String) {
        self.id = UUID().uuidString
        self.name = name
    }
    static func == (lhs: TestTag, rhs: TestTag) -> Bool { lhs.id == rhs.id }
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
        // The last matching rule re-includes B.
        #expect(filter.matches(tagIDs: Set([b.id])))
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

    @Test func hasTagAndItsExclusionMatchCardinality() {
        let a = TestTag(name: "A")
        let tagged = TagFilter<TestTag>(startAll: false,
            operations: [.init(criterion: .hasTag, add: true)])
        let untagged = TagFilter<TestTag>(startAll: true,
            operations: [.init(criterion: .hasTag, add: false)])
        #expect(tagged.matches(tagIDs: [a.id]))
        #expect(!tagged.matches(tagIDs: []))
        #expect(untagged.matches(tagIDs: []))
        #expect(!untagged.matches(tagIDs: [a.id]))
    }

    @Test func cardinalityRulesFollowOrderedOverrideSemantics() {
        let a = TestTag(name: "A")
        let filter = TagFilter<TestTag>(startAll: true, operations: [
            .init(criterion: .hasTag, add: false),
            .init(tagID: a.id, add: true)
        ])
        #expect(filter.matches(tagIDs: []))
        #expect(filter.matches(tagIDs: [a.id]))
        let b = TestTag(name: "B")
        #expect(!filter.matches(tagIDs: [b.id]))
        #expect(filter.invalidTagIDs(availableTags: [a,b]).isEmpty)
    }

    @Test func newAndLegacyOperationEncodingRoundTrips() throws {
        let a = TestTag(name: "A")
        let filter = TagFilter<TestTag>(startAll: false, operations: [
            .init(tagID: a.id, add: true),
            .init(criterion: .hasTag, add: false)
        ])
        let data = try JSONEncoder().encode(filter)
        let copied = try JSONDecoder().decode(TagFilter<TestTag>.self, from: data)
        #expect(copied == filter)
        let legacy = Data("{\"startAll\":true,\"operations\":[{\"tagID\":\"a\",\"add\":false}]}".utf8)
        let decoded = try JSONDecoder().decode(TagFilter<TestTag>.self, from: legacy)
        #expect(decoded.operations == [.init(tagID: "a", add: false)])
    }

    @Test func legacyHasNoTagMigratesWithoutChangingOrderedResults() throws {
        let a = TestTag(name: "A")
        // A legacy rule after a named-tag rule must affect only the empty set.
        let legacy = Data("""
            {"startAll":false,"operations":[
              {"tagID":"\(a.id)","add":true},
              {"condition":"hasNoTag","add":true},
              {"condition":"hasTag","add":false},
              {"tagID":"\(a.id)","add":true}]}
            """.utf8)
        let decoded = try JSONDecoder().decode(TagFilter<TestTag>.self, from: legacy)
        #expect(decoded.matches(tagIDs: []))
        #expect(decoded.matches(tagIDs: [a.id]))
        #expect(!decoded.matches(tagIDs: ["other"]))
        let encoded = try JSONEncoder().encode(decoded)
        #expect(!String(decoding: encoded, as: UTF8.self).contains("hasNoTag"))
        #expect(try JSONDecoder().decode(TagFilter<TestTag>.self, from: encoded) == decoded)

        // Repeated legacy rules use the LAST matching rule for an empty set.
        let repeated = Data("""
            {"startAll":true,"operations":[
              {"condition":"hasNoTag","add":true},
              {"condition":"hasNoTag","add":false}]}
            """.utf8)
        let migrated = try JSONDecoder().decode(TagFilter<TestTag>.self, from: repeated)
        #expect(!migrated.matches(tagIDs: []))
        #expect(migrated.matches(tagIDs: [a.id]))
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
