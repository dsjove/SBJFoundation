import Testing
@testable import SBJStructure

@Suite("Model collection traversal")
struct SBJCollectionTraversalTests {
    struct Item { let id: Int; let title: String }

    @Test("array produces stable identity independently of position")
    func arrayIdentity() {
        let first = [Item(id: 42, title: "One"), Item(id: 7, title: "Two")]
        let before = SBJCollectionTraversal.array(first, itemTitleKey: "title", itemIdentifierKey: "id")
        let after = SBJCollectionTraversal.array(first.reversed(), itemTitleKey: "title", itemIdentifierKey: "id")
        #expect(before[0].identifier == after[1].identifier)
        #expect(before[0].location != after[1].location)
        #expect(before[0].title == "One")
    }

    @Test("duplicate identifiers fall back to slot identities")
    func duplicates() {
        let nodes = SBJCollectionTraversal.array([Item(id: 1, title: "A"), Item(id: 1, title: "B")], itemIdentifierKey: "id")
        #expect(nodes.map(\.identifier) == ["item:slot:0", "item:slot:1"])
    }

    @Test("identified array element resolves after reorder and insertion")
    func currentIndexTracksIdentity() {
        let initial = [Item(id: 42, title: "One"), Item(id: 7, title: "Two")]
        let item = SBJCollectionTraversal.array(initial, itemIdentifierKey: "id")[0]
        #expect(!SBJCollectionTraversal.isPositional(item))
        let moved = [Item(id: 99, title: "New"), initial[1], initial[0]]
        #expect(SBJCollectionTraversal.currentIndex(of: item, in: moved, itemIdentifierKey: "id") == 2)
        #expect(SBJCollectionTraversal.currentIndex(of: item, in: [initial[1]], itemIdentifierKey: "id") == nil)
    }

    @Test("duplicate identifiers cannot silently select another element")
    func currentIndexRejectsAmbiguousIdentity() {
        let initial = [Item(id: 42, title: "One"), Item(id: 7, title: "Two")]
        let item = SBJCollectionTraversal.array(initial, itemIdentifierKey: "id")[0]
        let duplicates = [initial[0], Item(id: 42, title: "Duplicate")]
        #expect(SBJCollectionTraversal.currentIndex(of: item, in: duplicates, itemIdentifierKey: "id") == nil)
    }

    @Test("positional array entries keep editor slot semantics")
    func currentIndexFallsBackToPosition() {
        let initial = [Item(id: 1, title: "A"), Item(id: 1, title: "B")]
        let item = SBJCollectionTraversal.array(initial, itemIdentifierKey: "id")[1]
        #expect(SBJCollectionTraversal.isPositional(item))
        #expect(SBJCollectionTraversal.currentIndex(of: item, in: initial, itemIdentifierKey: "id") == 1)
        #expect(SBJCollectionTraversal.currentIndex(of: item, in: [initial[0]], itemIdentifierKey: "id") == nil)
    }

    @Test("dictionary and set traverse in deterministic order")
    func unorderedCollections() {
        #expect(SBJCollectionTraversal.set(Set(["b", "a"])).map(\.value) == ["a", "b"])
        #expect(SBJCollectionTraversal.dictionary(["b": 2, "a": 1]).map { $0.value.key } == ["a", "b"])
    }
}

@Suite("Comparable collection presentation ordering")
struct SBJCollectionPresentationSortingTests {
    @Test("set presentation orders comparable elements without mutating the set")
    func setPresentationOrder() {
        let values: Set<Int> = [2, 4, 1]
        #expect(values.sortedForPresentation(direction: .ascending) == [1, 2, 4])
        #expect(values.sortedForPresentation(direction: .descending) == [4, 2, 1])
        #expect(values == Set([2, 4, 1]))
    }

    @Test("dictionary value presentation breaks equal values by key")
    func dictionaryValueOrder() {
        let values = ["b": 2, "a": 2, "c": 1]
        #expect(values.sortedForPresentation(direction: .ascending, by: .value).map(\.key) == ["c", "a", "b"])
        #expect(values.sortedForPresentation(direction: .descending, by: .value).map(\.key) == ["b", "a", "c"])
        #expect(values.sortedForPresentation(direction: .ascending, by: .key).map(\.key) == ["a", "b", "c"])
        #expect(values.count == 3)
    }
}
