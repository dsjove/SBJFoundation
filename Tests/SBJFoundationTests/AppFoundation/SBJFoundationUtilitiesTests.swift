import Foundation
import Testing
@testable import SBJFoundation

@Suite("Foundation utilities")
struct SBJFoundationUtilitiesTests {
    @Test func collectionUtilities() {
        #expect([1, 2, 1, 3, 2].removingDuplicatesPreservingOrder() == [1, 2, 3])
        #expect(Set([1, 2, 1, 3, 2].removingDuplicatesUnordered()) == Set([1, 2, 3]))
        let grouped = ["a", "bb", "c"].grouped(by: \.count)
        #expect(grouped[1] == ["a", "c"])
        #expect(grouped[2] == ["bb"])
    }

    @Test func identifiedURLUsesGenericIdentityWrapper() {
        let value: IdentifiedURL = Identified(URL(string: "https://example.com")!)
        #expect(value.value.absoluteString == "https://example.com")
    }

    @Test func dictionaryRenamePreservesOptionalNilValue() {
        var values: [String: Int?] = [:]
        values.updateValue(nil, forKey: "old")

        #expect(values.keys.contains("old"))
        let renamed = values.sbjRenameKey("old", to: "new")
        #expect(renamed)
        #expect(!values.keys.contains("old"))
        #expect(values.keys.contains("new"))
        #expect(values["new"] != nil)
    }

    @Test func dictionaryUpdatePreservesOptionalNilEntry() {
        var values: [String: Int?] = ["key": 1]
        values.updateValue(nil, forKey: "key")

        #expect(values.keys.contains("key"))
        #expect(values["key"] != nil)
    }

    @Test func dictionaryRenameRejectsCollisionsAndPreservesValues() {
        var values = ["one": 1, "two": 2]
        let collisionRejected = !values.sbjRenameKey("one", to: "two")
        #expect(collisionRejected)
        #expect(values == ["one": 1, "two": 2])

        let renameSucceeded = values.sbjRenameKey("one", to: "three")
        #expect(renameSucceeded)
        #expect(values == ["three": 1, "two": 2])
    }

    @Test func collectionMutationHelpersHandleNoOpMissingAndCollisionCases() {
        var set: Set<String> = ["one", "two"]
        let sameValueSucceeded = set.sbjReplace("one", with: "one")
        #expect(sameValueSucceeded)
        #expect(set == ["one", "two"])
        let missingRejected = !set.sbjReplace("missing", with: "three")
        #expect(missingRejected)
        let collisionRejected = !set.sbjReplace("one", with: "two")
        #expect(collisionRejected)
        #expect(set == ["one", "two"])

        var dictionary = ["one": 1, "two": 2]
        let sameKeySucceeded = dictionary.sbjRenameKey("one", to: "one")
        #expect(sameKeySucceeded)
        let missingKeyRejected = !dictionary.sbjRenameKey("missing", to: "three")
        #expect(missingKeyRejected)
        let keyCollisionRejected = !dictionary.sbjRenameKey("one", to: "two")
        #expect(keyCollisionRejected)
        #expect(dictionary == ["one": 1, "two": 2])
    }

    @Test func publicCollectionMutationExtensionsRejectCollisions() {
        var set: Set<String> = ["one", "two"]
        let replacementSucceeded = set.sbjReplace("one", with: "three")
        #expect(replacementSucceeded)
        #expect(set == ["two", "three"])
        let setCollisionRejected = !set.sbjReplace("two", with: "three")
        #expect(setCollisionRejected)
        #expect(set == ["two", "three"])

        var dictionary = ["one": 1, "two": 2]
        let renameSucceeded = dictionary.sbjRenameKey("one", to: "three")
        #expect(renameSucceeded)
        #expect(dictionary == ["three": 1, "two": 2])
        let dictionaryCollisionRejected = !dictionary.sbjRenameKey("two", to: "three")
        #expect(dictionaryCollisionRejected)
        #expect(dictionary == ["three": 1, "two": 2])
    }
}
