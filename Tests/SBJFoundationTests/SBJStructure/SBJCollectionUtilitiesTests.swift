import Foundation
import Testing
@testable import SBJFoundation

private struct CollectionUtilityItem: Hashable {
    var name: String
    var rank: Int
}

private struct CollectionUtilityOptionalTitleItem: Hashable {
    var name: String?
}

@Suite("Collection utilities")
struct SBJCollectionUtilitiesTests {
    @Test func setOrderingUsesNaturalScalarOrder() {
        #expect(SBJCollectionOrdering.sorted(Set(["10", "2", "1"])) == ["1", "2", "10"])
        #expect(SBJCollectionOrdering.sorted(Set([3, 1, 2])) == [1, 2, 3])
    }

    @Test func dictionaryOrderingUsesNaturalKeyOrder() {
        let dictionary = ["10": 10, "2": 2, "1": 1]
        #expect(SBJCollectionOrdering.sortedEntries(dictionary).map(\.key) == ["1", "2", "10"])
    }

    @Test func nonScalarOrderingUsesReadableElementIdentity() {
        let values: Set<CollectionUtilityItem> = [
            .init(name: "Zulu", rank: 1),
            .init(name: "Alpha", rank: 2),
        ]

        let first = SBJCollectionOrdering.sorted(values)
        let second = SBJCollectionOrdering.sorted(values)
        #expect(first == second)
    }

    @Test func uniqueIdentifierFollowsReorderingAndInsertion() {
        let original = [CollectionUtilityItem(name: "Alpha", rank: 1),
                        CollectionUtilityItem(name: "Beta", rank: 2)]
        let id = SBJCollectionItemIdentification.stableIdentifier(
            for: original[1], itemIdentifierKey: "name"
        )!
        #expect(SBJCollectionItemIdentification.uniqueIndex(
            in: original, identifier: id, itemIdentifierKey: "name") == 1)
        let reordered = [original[1], CollectionUtilityItem(name: "New", rank: 3), original[0]]
        #expect(SBJCollectionItemIdentification.uniqueIndex(
            in: reordered, identifier: id, itemIdentifierKey: "name") == 0)
        #expect(SBJCollectionItemIdentification.uniqueIndex(
            in: [original[0]], identifier: id, itemIdentifierKey: "name") == nil)
    }

    @Test func ambiguousIdentifierNeverSelectsFirstMatchingElement() {
        let elements = [CollectionUtilityItem(name: "Duplicate", rank: 1),
                        CollectionUtilityItem(name: "Duplicate", rank: 2)]
        let id = SBJCollectionItemIdentification.stableIdentifier(
            for: elements[0], itemIdentifierKey: "name"
        )!
        #expect(SBJCollectionItemIdentification.uniqueIndex(
            in: elements, identifier: id, itemIdentifierKey: "name") == nil)
    }

    @Test func configuredItemTitleUsesNamedProperty() {
        let item = CollectionUtilityItem(name: "Beta", rank: 7)
        #expect(
            SBJCollectionItemIdentification.title(for: item, itemTitleKey: "name") == "Beta"
        )
    }

    @Test func arrayTitleFallsBackToStructuralIndex() {
        let item = CollectionUtilityItem(name: "Beta", rank: 7)
        #expect(
            SBJCollectionItemIdentification.arrayTitle(for: item, index: 3) == "[3]"
        )
        #expect(
            SBJCollectionItemIdentification.arrayTitle(
                for: item,
                index: 3,
                itemTitleKey: "name"
            ) == "Beta"
        )
    }

    @Test func missingOrEmptyConfiguredTitleFallsBack() {
        let item = CollectionUtilityOptionalTitleItem(name: nil)
        let title = SBJCollectionItemIdentification.title(for: item, itemTitleKey: "name")
        #expect(!title.isEmpty)
        #expect(
            SBJCollectionItemIdentification.arrayTitle(
                for: item,
                index: 4,
                itemTitleKey: "name"
            ) == "[4]"
        )
    }

    @Test func configuredTitleUnwrapsOptionalProperties() {
        let populated = CollectionUtilityOptionalTitleItem(name: "Beta")
        #expect(
            SBJCollectionItemIdentification.configuredTitle(
                for: populated,
                itemTitleKey: "name"
            ) == "Beta"
        )

        let empty = CollectionUtilityOptionalTitleItem(name: nil)
        #expect(
            SBJCollectionItemIdentification.configuredTitle(
                for: empty,
                itemTitleKey: "name"
            ) == nil
        )
    }
}
