import Testing
import SBJStructure

@Suite
struct SBJStructuralCollectionOperationTests {
    @Test func arraysSupportSequencedOperations() throws {
        let source = [10, 20, 30]
        let inserted = try SBJStructuralCollectionMutation.applying(.insert(15, at: 1), to: source) as! [Int]
        #expect(inserted == [10, 15, 20, 30])
        let moved = try SBJStructuralCollectionMutation.applying(.move(from: 0, to: 3), to: inserted) as! [Int]
        #expect(moved == [15, 20, 30, 10])
        let duplicated = try SBJStructuralCollectionMutation.applying(.duplicate(at: 1), to: moved) as! [Int]
        #expect(duplicated == [15, 20, 20, 30, 10])
        let removed = try SBJStructuralCollectionMutation.applying(.remove(at: 2), to: duplicated) as! [Int]
        #expect(removed == moved)
        #expect(source == [10, 20, 30])
    }

    @Test func dictionaryDistinguishesInsertReplaceAndUpsert() throws {
        let original = ["one": 1]
        let inserted = try SBJStructuralCollectionMutation.applying(.insertKey(key: "two", value: 2), to: original) as! [String:Int]
        #expect(inserted == ["one": 1, "two": 2])
        #expect(throws: SBJStructuralCollectionOperationError.collectionCollision) {
            try SBJStructuralCollectionMutation.applying(.insertKey(key: "one", value: 9), to: original)
        }
        #expect(throws: SBJStructuralCollectionOperationError.missingElement) {
            try SBJStructuralCollectionMutation.applying(.replaceKey(key: "missing", value: 9), to: original)
        }
        let replaced = try SBJStructuralCollectionMutation.applying(.replaceKey(key: "one", value: 9), to: original) as! [String:Int]
        #expect(replaced["one"] == 9)
        let upserted = try SBJStructuralCollectionMutation.applying(.put(key: "three", value: 3), to: original) as! [String:Int]
        #expect(upserted["three"] == 3)
    }

    @Test func setOperationsRejectDuplicatesAndMissingMembers() throws {
        let original: Set<Int> = [1, 2]
        #expect(throws: SBJStructuralCollectionOperationError.collectionCollision) {
            try SBJStructuralCollectionMutation.applying(.insertMember(1), to: original)
        }
        #expect(throws: SBJStructuralCollectionOperationError.collectionCollision) {
            try SBJStructuralCollectionMutation.applying(.replaceMember(old: 1, new: 2), to: original)
        }
        #expect(throws: SBJStructuralCollectionOperationError.missingElement) {
            try SBJStructuralCollectionMutation.applying(.removeMember(3), to: original)
        }
        let replaced = try SBJStructuralCollectionMutation.applying(.replaceMember(old: 1, new: 4), to: original) as! Set<Int>
        #expect(replaced == [2, 4])
        #expect(original == [1, 2])
    }

    @Test func optionalIsACollectionWithCardinalityZeroOrOne() throws {
        let empty: Int? = nil
        let added = try SBJStructuralCollectionMutation.applying(.insert(7, at: 0), to: empty as Any) as! Int?
        #expect(added == 7)
        #expect(throws: SBJStructuralCollectionOperationError.collectionCollision) {
            try SBJStructuralCollectionMutation.applying(.append(8), to: added as Any)
        }
        let replaced = try SBJStructuralCollectionMutation.applying(.replace(at: 0, with: 8), to: added as Any) as! Int?
        #expect(replaced == 8)
        let removed = try SBJStructuralCollectionMutation.applying(.remove(at: 0), to: replaced as Any) as! Int?
        #expect(removed == nil)
        #expect(throws: SBJStructuralCollectionOperationError.invalidIndex) {
            try SBJStructuralCollectionMutation.applying(.remove(at: 0), to: empty as Any)
        }
        let cleared = try SBJStructuralCollectionMutation.applying(.clear, to: added as Any) as! Int?
        #expect(cleared == nil)
        #expect(empty == nil)
    }

    @Test func capabilitiesDependOnActualContainer() {
        let optional: String? = nil
        let optionalOperations = SBJStructuralCollectionMutation.supportedOperations(for: optional as Any)
        #expect(optionalOperations.contains(.insert))
        #expect(optionalOperations.contains(.setOptional))
        #expect(!optionalOperations.contains(.duplicate))
        #expect(SBJStructuralCollectionMutation.supportedOperations(for: 5).isEmpty)
        #expect(SBJStructuralCollectionMutation.supportedOperations(for: [1, 2]).contains(.move))
        #expect(!SBJStructuralCollectionMutation.supportedOperations(for: Set([1, 2])).contains(.move))
    }

    @Test func operationNomenclatureUsesSpecificTerms() {
        #expect(SBJCollectionOperationNomenclature.matching("add").isEmpty)
        #expect(SBJCollectionOperationNomenclature.matching("push") == [.append])
        #expect(SBJCollectionOperationNomenclature.matching("Add Member") == [.insertMember])
        #expect(SBJCollectionOperationNomenclature.matching("unset") == [.clearOptional])
        let setCapabilities = SBJStructuralCollectionMutation.supportedOperations(for: Set([1]))
        #expect(setCapabilities.contains(.insertMember))
        #expect(!setCapabilities.contains(.append))
    }

    @Test func invalidElementTypeCannotMutateACollection() {
        #expect(throws: SBJStructuralCollectionOperationError.typeMismatch) {
            try SBJStructuralCollectionMutation.applying(.append("incorrect"), to: [1, 2])
        }
        #expect(throws: SBJStructuralCollectionOperationError.typeMismatch) {
            try SBJStructuralCollectionMutation.applying(.put(key: 2, value: "incorrect"), to: ["one": 1])
        }
    }
}
