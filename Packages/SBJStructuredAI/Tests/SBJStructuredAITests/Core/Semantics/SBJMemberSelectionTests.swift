import SBJStructure
import Testing
@testable import SBJStructuredAI

@SBJStructure
struct SBJUnnamedMemberFixture: Codable, Hashable {
    var text = ""
    var score = 0
}

@SBJStructure
struct SBJMemberSelectionFixture {
    var notes = ["Meet at noon", "Find the wizard", "Find the book"]
    var records = [SBJUnnamedMemberFixture(text: "Red", score: 1), .init(text: "Blue", score: 2)]
    @SBJArray(elementName: \SBJUnnamedMemberFixture.text)
    var namedRecords = [SBJUnnamedMemberFixture(text: "Alpha"), .init(text: "")]
    var lookup = ["where content has:book": "literal value", "other": "Book of spells"]
    var tags: Set<String> = ["North", "South"]
}

@Suite("Collection member identity and content selection")
struct SBJMemberSelectionTests {
    private func id(_ snapshot: SBJSemanticReadSnapshot, _ path: [SBJStaticReadStructure.Step]) throws -> String {
        String(try #require(snapshot.declarationIdentifier(for: path)))
    }

    @Test func unnamedMembersHaveNoSyntheticName() throws {
        let root = SBJMemberSelectionFixture()
        let snapshot = try SBJSemanticReadSnapshot(instance: root)
        let notes = try id(snapshot, [.field("notes")])
        let records = try id(snapshot, [.field("records")])
        #expect(snapshot.declarationIdentifier(for: [.field("records"), .member, .memberName]) == nil)
        #expect(snapshot.declarationIdentifier(for: [.field("notes"), .member, .memberName]) == nil)
        #expect(try snapshot.modelQuery(.keys, stringKeyPath: [notes]).available?.members.map(\.key) == ["@1", "@2", "@3"])
        #expect(try snapshot.modelQuery(.keys, stringKeyPath: [records]).available?.members.map(\.key) == ["@1", "@2"])
        #expect(try snapshot.modelQuery(.read, stringKeyPath: [records, "Item 1"]).memberRequest != nil)
        let named = try id(snapshot, [.field("namedRecords")])
        let name = try id(snapshot, [.field("namedRecords"), .member, .memberName])
        #expect(try snapshot.modelQuery(.read, stringKeyPath: [named, "Alpha", name]).readValue == .text("Alpha"))
        #expect(try snapshot.modelQuery(.read, stringKeyPath: [named, "@2", name]).state == .unset)
        #expect(try SBJCompactStructureTestDecoder.expand(snapshot.structuralDescription()) == snapshot.structuralDescription(usesTemplates: false))
    }

    @Test func contentSelectionAndAmbiguity() throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJMemberSelectionFixture())
        let notes = try id(snapshot, [.field("notes")])
        let records = try id(snapshot, [.field("records")])
        let score = try id(snapshot, [.field("records"), .member, .field("score")])
        #expect(try snapshot.modelQuery(.read, stringKeyPath: [notes, "where content has:WIZARD"]).readValue == .text("Find the wizard"))
        #expect(try snapshot.modelQuery(.read, stringKeyPath: [notes, "where content is:Find the book"]).readValue == .text("Find the book"))
        #expect(try snapshot.modelQuery(.read, stringKeyPath: [notes, "where content has:Find"]).memberRequest != nil)
        #expect(try snapshot.modelQuery(.read, stringKeyPath: [notes, "where content has:"]).memberRequest != nil)
        #expect(try snapshot.modelQuery(.read, stringKeyPath: [notes, "where content is:find the book"]).memberRequest != nil)
        #expect(try snapshot.modelQuery(.read, stringKeyPath: [records, "where content has:Blue", score]).readValue == .signed(2))
    }

    @Test func selectorSyntaxDoesNotShadowLiteralKeys() throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJMemberSelectionFixture())
        let lookup = try id(snapshot, [.field("lookup")])
        let value = try id(snapshot, [.field("lookup"), .member, .field("value")])
        let keys = try snapshot.modelQuery(.keys, stringKeyPath: [lookup])
        #expect(keys.available?.members.contains(where: { $0.key == "literal:where content has:book" }) == true)
        #expect(try snapshot.modelQuery(.read, stringKeyPath: [lookup, "literal:where content has:book", value]).readValue == .text("literal value"))
        #expect(try snapshot.modelQuery(.read, stringKeyPath: [lookup, "where content has:book", value]).readValue == .text("Book of spells"))
    }

    @Test func bothMutationToolsUseContentResolution() throws {
        let root = SBJMemberSelectionFixture()
        let snapshot = try SBJSemanticReadSnapshot(instance: root)
        let notes = try id(snapshot, [.field("notes")])
        let proposal = try SBJLeafMutation.prepare(root, snapshot: snapshot, keyPath: [notes, "where content has:wizard"], value: "Found the wizard")
        let changed = try SBJStructuralMutation.replacing(root, at: proposal.location[...], with: proposal.replacement)
        #expect(changed.notes == ["Meet at noon", "Found the wizard", "Find the book"])
        #expect(throws: (any Error).self) {
            try SBJLeafMutation.prepare(root, snapshot: snapshot, keyPath: [notes, "where content has:Find"], value: "Unsafe")
        }
        let result = try SBJCollectionMutation.prepare(root, snapshot: snapshot, request: .init(keyPath: [notes], operation: "remove", member: "where content has:book"))
        if case .proposal(let change) = result {
            let removed = try SBJStructuralMutation.replacing(root, at: change.location[...], with: change.replacement)
            #expect(removed.notes == ["Meet at noon", "Find the wizard"])
        } else { Issue.record("Expected mutation proposal") }
        #expect(throws: (any Error).self) {
            try SBJCollectionMutation.prepare(root, snapshot: snapshot, request: .init(keyPath: [notes], operation: "remove", member: "where content has:Find"))
        }
    }
}
