import Foundation
import SBJStructure
import Testing
@testable import SBJStructuredAI

@Suite("Leaf mutation resolution and conversion")
struct SBJLeafMutationTests {
    private func id(_ snapshot: SBJSemanticReadSnapshot, _ path: [SBJStaticReadStructure.Step]) throws -> String {
        String(try #require(snapshot.declarationIdentifier(for: path)))
    }

    private func candidate(_ root: SBJSemanticReadFixture, _ snapshot: SBJSemanticReadSnapshot,
                           _ path: [String], _ value: String) throws -> SBJSemanticReadFixture {
        let proposal = try SBJLeafMutation.prepare(root, snapshot: snapshot, keyPath: path, value: value)
        return try SBJStructuralMutation.replacing(root, at: proposal.location[...], with: proposal.replacement)
    }

    @Test func exactRootAndNestedPaths() throws {
        let root = SBJSemanticReadFixture()
        let snapshot = try SBJSemanticReadSnapshot(instance: root)
        let level = try id(snapshot, [.field("level")])
        let items = try id(snapshot, [.field("items")])
        let rank = try id(snapshot, [.field("items"), .member, .field("rank")])
        let proposal = try SBJLeafMutation.prepare(root, snapshot: snapshot, keyPath: [level], value: "12")
        #expect(proposal.change.oldValue == "9")
        #expect(proposal.change.proposedValue == "12")
        #expect(try candidate(root, snapshot, [level], "12").level == 12)
        let changed = try candidate(root, snapshot, [items, "@2", rank], "13")
        #expect(changed.items.map(\.rank) == [7, 13])
        #expect(root.items.map(\.rank) == [7, 8])
        #expect(throws: (any Error).self) { try candidate(root, snapshot, [items, "Same", rank], "13") }
        #expect(throws: (any Error).self) { try candidate(root, snapshot, [items, rank], "13") }
    }

    @Test func dictionarySetAndOptionalLeafLocations() throws {
        let root = SBJSemanticReadFixture()
        let snapshot = try SBJSemanticReadSnapshot(instance: root)
        let lookup = try id(snapshot, [.field("lookup")])
        let value = try id(snapshot, [.field("lookup"), .member, .field("value")])
        let key = try id(snapshot, [.field("lookup"), .member, .field("key")])
        let tags = try id(snapshot, [.field("tags")])
        let optionalItems = try id(snapshot, [.field("optionalItems")])
        #expect(try candidate(root, snapshot, [lookup, "a/b~c", value], "31").lookup["a/b~c"] == .some(31))
        #expect(throws: (any Error).self) { try candidate(root, snapshot, [lookup, "a/b~c", key], "new") }
        #expect(throws: (any Error).self) { try candidate(root, snapshot, [lookup, "nil", value], "31") }
        #expect(try candidate(root, snapshot, [tags, "North"], "East").tags == ["East", "South"])
        #expect(throws: (any Error).self) { try candidate(root, snapshot, [tags, "North"], "South") }
        #expect(try candidate(root, snapshot, [optionalItems, "@1"], "5").optionalItems == [5, nil, 3])
        #expect(throws: (any Error).self) { try candidate(root, snapshot, [optionalItems, "@2"], "5") }
    }

    @Test func rejectsImmutableComputedCompoundAndInvalidPaths() throws {
        let root = SBJSemanticReadFixture()
        let snapshot = try SBJSemanticReadSnapshot(instance: root)
        for name in ["fixed", "doubled", "items", "absent", "choice"] {
            let field = try id(snapshot, [.field(name)])
            #expect(throws: (any Error).self) { try candidate(root, snapshot, [field], "5") }
        }
        #expect(throws: (any Error).self) { try candidate(root, snapshot, [], "5") }
        #expect(throws: (any Error).self) { try candidate(root, snapshot, ["level"], "5") }
    }

    @Test func exactScalarAndEnumConversion() throws {
        #expect(try SBJLeafMutation.convert("  literal text  ", matching: "old") as? String == "  literal text  ")
        #expect(try SBJLeafMutation.convert("18446744073709551615", matching: UInt64(0)) as? UInt64 == .max)
        #expect(try SBJLeafMutation.convert("1234567890.123456789", matching: Decimal.zero) as? Decimal == Decimal(string: "1234567890.123456789"))
        #expect(try SBJLeafMutation.convert("second", matching: SBJSemanticReadFixtureKey.first) as? SBJSemanticReadFixtureKey == .second)
        #expect(throws: (any Error).self) { try SBJLeafMutation.convert("256", matching: UInt8(0)) }
        #expect(throws: (any Error).self) { try SBJLeafMutation.convert("NaN", matching: 0.0) }
        #expect(throws: (any Error).self) { try SBJLeafMutation.convert("12junk", matching: Decimal.zero) }
        #expect(throws: (any Error).self) { try SBJLeafMutation.convert("unknown", matching: SBJSemanticReadFixtureKey.first) }
        let weight = try #require(try SBJLeafMutation.convert("3.5", matching: UnitValue<MassUnit>(2.5, unit: .kilogram)) as? UnitValue<MassUnit>)
        #expect(weight.value == 3.5)
        #expect(weight.unit == .kilogram)
    }

    @Test @MainActor func candidateUsesExistingTransactionAndInvariant() throws {
        let document = SBJAssistantDocument(id: "doc", revision: 1, model: SBJTransactionFixture(), allowsEditing: true)
        let snapshot = try SBJSemanticReadSnapshot(instance: document.model)
        let path = [try id(snapshot, [.field("level")])]
        var saved: SBJTransactionFixture?
        let transaction = SBJAssistantTransaction(snapshot: { document }, persist: { model, _, _, completion in
            saved = model
            completion(.success(()))
        })
        let invalid = try SBJLeafMutation.prepare(document.model, snapshot: snapshot, keyPath: path, value: "21")
        #expect(throws: (any Error).self) {
            try transaction.stage(document: document, location: invalid.location, replacement: invalid.replacement, changes: [invalid.change])
        }
        #expect(transaction.summary == nil)
        let valid = try SBJLeafMutation.prepare(document.model, snapshot: snapshot, keyPath: path, value: "14")
        try transaction.stage(document: document, location: valid.location, replacement: valid.replacement, changes: [valid.change])
        #expect(saved == nil)
        #expect(document.model.level == 9)
        transaction.approve { outcome in
            if case .applied = outcome {} else { Issue.record("Expected applied outcome") }
        }
        #expect(saved?.level == 14)
    }
}
