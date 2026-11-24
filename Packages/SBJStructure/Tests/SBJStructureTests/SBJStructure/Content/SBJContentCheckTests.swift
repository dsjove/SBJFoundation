import Testing
@testable import SBJStructure

@SBJStructure
private struct ContentLeaf: Codable {
    var filled: String
    var empty: String
}

@SBJStructure
private struct ContentBranch: Codable {
    var title: String
    var leaf: ContentLeaf
}

@SBJStructure
private struct CollectionContent: Codable {
    var array: [String]
    var set: Set<String>
    var dictionary: [String: String]
}

@SBJStructure
private enum AssociatedContent: Codable {
    case text(String)
    case pair(name: String, value: Int)
}

struct SBJContentCheckTests {
    @Test func structuredValueFindsEmptyNestedProperty() {
        let value = ContentBranch(
            title: "Branch",
            leaf: ContentLeaf(filled: "present", empty: "")
        )

        #expect(value.hasContent)
        #expect(SBJContentCheck.containsEmptyContent(value))
        #expect(value.sbjContainsEmptyContent())
    }

    @Test func fullyPopulatedStructuredValueHasNoEmptyContent() {
        let value = ContentBranch(
            title: "Branch",
            leaf: ContentLeaf(filled: "present", empty: "also present")
        )

        #expect(!SBJContentCheck.containsEmptyContent(value))
    }

    @Test func traversesOptionalsAndCollections() {
        #expect(SBJContentCheck.containsEmptyContent(Optional<String>.none))
        #expect(SBJContentCheck.containsEmptyContent(["present", ""]))
        #expect(SBJContentCheck.containsEmptyContent(Set(["present", ""])))
        #expect(SBJContentCheck.containsEmptyContent(["good": "present", "bad": ""]))

        let full = CollectionContent(
            array: ["one"],
            set: ["two"],
            dictionary: ["three": "four"]
        )
        #expect(!SBJContentCheck.containsEmptyContent(full))
    }

    @Test func dictionaryKeysDoNotParticipateInEmptyValueDetection() {
        let value = ["": "present"]
        #expect(!SBJContentCheck.containsEmptyContent(value))
    }

    @Test func traversesStructuredAssociatedEnumPayloads() {
        #expect(SBJContentCheck.containsEmptyContent(AssociatedContent.text("")))
        #expect(!SBJContentCheck.containsEmptyContent(AssociatedContent.text("present")))
        #expect(SBJContentCheck.containsEmptyContent(AssociatedContent.pair(name: "", value: 1)))
    }

    @Test func callerCanTreatATypeAsAtomicLeaf() {
        let value = ContentBranch(
            title: "Branch",
            leaf: ContentLeaf(filled: "present", empty: "")
        )

        let containsEmpty = SBJContentCheck.containsEmptyContent(value) { type in
            type == ContentLeaf.self
        }

        #expect(!containsEmpty)
    }

    @Test func atomicLeafStillReportsWhenLeafItselfHasNoContent() {
        let value = ContentLeaf(filled: "", empty: "")

        let containsEmpty = SBJContentCheck.containsEmptyContent(value) { type in
            type == ContentLeaf.self
        }

        #expect(containsEmpty)
    }
}
