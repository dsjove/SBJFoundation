import Foundation
import Testing
@testable import SBJStructure

private struct Snapshot: Codable, Equatable {
    var name: String
    var count: Int
}

struct ModelUtilitiesTests {
    @Test func codableSnapshotAndComparison() {
        let original = Snapshot(name: "one", count: 1)
        #expect(original.sbjCodableCopy() == original)
        #expect(!original.sbjEncodedIsDifferent(from: original))
        #expect(original.sbjEncodedIsDifferent(from: Snapshot(name: "one", count: 2)))
    }

    @Test func setReplacementPreservesCollisionSemantics() {
        var values: Set<String> = ["one", "two"]
        let collisionRejected = !values.sbjReplace("one", with: "two")
        #expect(collisionRejected)
        #expect(values == ["one", "two"])
        let replaced = values.sbjReplace("one", with: "three")
        #expect(replaced)
        #expect(values == ["two", "three"])
        let sameValueAccepted = values.sbjReplace("three", with: "three")
        #expect(sameValueAccepted)
        let missingRejected = !values.sbjReplace("missing", with: "four")
        #expect(missingRejected)
    }
}
