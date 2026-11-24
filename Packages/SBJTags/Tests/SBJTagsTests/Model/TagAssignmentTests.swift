import Foundation
import Observation
import Testing
import SBJStructure
@testable import SBJTags

@MainActor
@Observable
private final class AssignedTag: Tagging {
    let id: UUID
    var name: String
    var color: CodableColor

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
        self.color = CodableColor(0.2, 0.4, 0.8)
    }
    static func == (lhs: AssignedTag, rhs: AssignedTag) -> Bool { lhs.id == rhs.id }
}

@MainActor
private struct AssignedOwner: TagUser {
    let id = UUID()
    var __tags: [AssignedTag]?
    var __primaryTagID: UUID?
}

@Suite("Tag assignment semantics")
@MainActor
struct TagAssignmentTests {
    @Test func firstAssignmentBecomesPrimaryAndDuplicateIsIgnored() {
        let one = AssignedTag(name: "One")
        let two = AssignedTag(name: "Two")
        var owner = AssignedOwner()
        owner.addTag(one)
        owner.addTag(one)
        #expect(owner.tagCount == 1)
        #expect(owner.isTagPrimary(one))
        owner.addTag(two)
        #expect(owner.tagCount == 2)
        #expect(owner.isTagPrimary(one))
        owner.togglePrimary(two)
        #expect(owner.isTagPrimary(two))
        owner.togglePrimary(two)
        #expect(owner.__primaryTagID == nil)
        #expect(owner.hasTag(two))
    }

    @Test func removingPrimaryClearsOnlyPrimaryDesignation() {
        let one = AssignedTag(name: "One")
        let two = AssignedTag(name: "Two")
        var owner = AssignedOwner()
        owner.addTag(one)
        owner.addTag(two)
        owner.removeTag(one)
        #expect(owner.tagCount == 1)
        #expect(owner.__primaryTagID == nil)
        #expect(owner.hasTag(two))
    }

    @Test func portableTagEncodesItsValueWithoutPersistenceGraph() throws {
        let source = AssignedTag(name: "Portable")
        let value = source.codableValue
        let encoded = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(TagCodableValue<UUID>.self, from: encoded)
        #expect(decoded.id == source.id)
        #expect(decoded.name == source.name)
        #expect(decoded.color == source.color)
    }
}
