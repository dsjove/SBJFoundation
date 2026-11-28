import SBJStructure
import Testing
@testable import SBJStructuredAI

@Suite("Collection mutation resolution and conversion")
struct SBJCollectionMutationTests {
    private func request(_ root: SBJSemanticReadFixture, _ field: String, _ operation: String,
                         member: String? = nil, position: Int? = nil, value: String? = nil) throws -> SBJCollectionMutation.Result {
        let snapshot = try SBJSemanticReadSnapshot(instance: root)
        let id = String(try #require(snapshot.declarationIdentifier(for: [.field(field)])))
        return try SBJCollectionMutation.prepare(root, snapshot: snapshot,
            request: .init(keyPath: [id], operation: operation, member: member, position: position, value: value))
    }
    private func proposal(_ result: SBJCollectionMutation.Result) throws -> SBJLeafMutation.Proposal {
        if case .proposal(let proposal) = result { return proposal }
        Issue.record("Expected mutation proposal")
        throw SBJStructuralCollectionOperationError.unsupportedOperation
    }
    private func candidate(_ root: SBJSemanticReadFixture, _ field: String, _ operation: String,
                           member: String? = nil, position: Int? = nil, value: String? = nil) throws -> SBJSemanticReadFixture {
        let change = try proposal(request(root, field, operation, member: member, position: position, value: value))
        return try SBJStructuralMutation.replacing(root, at: change.location[...], with: change.replacement)
    }

    @Test func arrayOperationsAndDefaultCreation() throws {
        let root = SBJSemanticReadFixture()
        #expect(try candidate(root, "items", "add").items.map(\.rank) == [7, 8, 3])
        #expect(try candidate(root, "items", "insert", position: 2).items.map(\.rank) == [7, 3, 8])
        #expect(try candidate(root, "items", "delete", member: "@2").items.map(\.rank) == [7])
        #expect(try candidate(root, "items", "move", member: "@1", position: 2).items.map(\.rank) == [8, 7])
        #expect(try candidate(root, "items", "duplicate", member: "@1").items.map(\.rank) == [7, 7, 8])
        #expect(try candidate(root, "items", "replace", member: "@2").items.map(\.rank) == [7, 3])
        #expect(try candidate(root, "items", "clear").items.isEmpty)
        #expect(try candidate(root, "optionalItems", "add", value: "17").optionalItems == [2, nil, 3, 17])
        #expect(throws: (any Error).self) { try candidate(root, "items", "remove", member: "Same") }
        #expect(throws: (any Error).self) { try candidate(root, "items", "move", member: "@1", position: 0) }
        #expect(throws: (any Error).self) { try candidate(root, "items", "insert", position: 4) }
        #expect(throws: (any Error).self) { try candidate(root, "items", "add", value: "{}") }
        #expect(root.items.map(\.rank) == [7, 8])
    }

    @Test func dictionaryAndSetOperations() throws {
        let root = SBJSemanticReadFixture()
        #expect(try candidate(root, "lookup", "add", member: "new", value: "42").lookup["new"] == .some(42))
        #expect(try candidate(root, "lookup", "replace", member: "a/b~c", value: "12").lookup["a/b~c"] == .some(12))
        #expect(try candidate(root, "lookup", "put", member: "a/b~c", value: "13").lookup["a/b~c"] == .some(13))
        #expect(try candidate(root, "lookup", "remove", member: "nil").lookup.keys.contains("nil") == false)
        #expect(try candidate(root, "typedKeys", "add", member: "first").typedKeys[.first]?.rank == 3)
        #expect(try candidate(root, "typedKeys", "remove", member: "second").typedKeys.isEmpty)
        #expect(try candidate(root, "tags", "add", value: "East").tags == ["North", "South", "East"])
        #expect(try candidate(root, "tags", "replace", member: "North", value: "East").tags == ["East", "South"])
        #expect(try candidate(root, "tags", "remove", member: "North").tags == ["South"])
        #expect(throws: (any Error).self) { try candidate(root, "tags", "add", value: "North") }
        #expect(throws: (any Error).self) { try candidate(root, "lookup", "add", member: "a/b~c", value: "1") }
        #expect(throws: (any Error).self) { try candidate(root, "tags", "move", member: "North", position: 1) }
    }

    @Test func optionalOperationsAndCounts() throws {
        let root = SBJSemanticReadFixture()
        let created = try candidate(root, "absent", "set")
        #expect(created.absent?.neverInstantiatedField == "Never created")
        #expect(try candidate(created, "absent", "clear").absent == nil)
        #expect(try candidate(created, "absent", "remove", member: "@1").absent == nil)
        let initialized = try candidate(root, "absentCollection", "set")
        #expect(initialized.absentCollection?.isEmpty == true)
        let populated = try candidate(initialized, "absentCollection", "add")
        #expect(populated.absentCollection?.map(\.rank) == [3])
        #expect(try candidate(populated, "absentCollection", "clear").absentCollection?.isEmpty == true)
        #expect(try candidate(populated, "absentCollection", "clearOptional").absentCollection == nil)
        if case .count(let count) = try request(populated, "absentCollection", "countMembers") { #expect(count == 1) }
        else { Issue.record("Expected member count") }
        #expect(throws: (any Error).self) { try candidate(root, "items", "clear", member: "@1") }

        for (model, field, expected) in [(root, "items", 2), (root, "empty", 0), (root, "absent", 0), (created, "absent", 1)] {
            if case .count(let count) = try request(model, field, "count") { #expect(count == expected) }
            else { Issue.record("Expected count") }
        }
        #expect(throws: (any Error).self) { try request(root, "level", "count") }
    }

    @Test @MainActor func collectionProposalUsesTransactionAndInvariant() throws {
        let document = SBJAssistantDocument(id: "doc", revision: 1, model: SBJSemanticReadFixture(), allowsEditing: true)
        var saved: SBJSemanticReadFixture?
        let transaction = SBJAssistantTransaction(snapshot: { document }, persist: { model, _, _, completion in
            saved = model
            completion(.success(()))
        })
        let invalid = try proposal(request(document.model, "items", "clear"))
        #expect(throws: (any Error).self) {
            try transaction.stage(document: document, location: invalid.location, replacement: invalid.replacement, changes: [invalid.change])
        }
        let valid = try proposal(request(document.model, "items", "move", member: "@1", position: 2))
        #expect(valid.change.oldValue != valid.change.proposedValue)
        try transaction.stage(document: document, location: valid.location, replacement: valid.replacement, changes: [valid.change])
        #expect(saved == nil)
        transaction.approve { outcome in
            if case .applied = outcome {} else { Issue.record("Expected applied outcome") }
        }
        #expect(saved?.items.map(\.rank) == [8, 7])
    }
}
