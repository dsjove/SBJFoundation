import Foundation
import Testing
@testable import SBJLocalization

private struct DomainValue: HasContentCheckable {
    let text: String
    var hasContent: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    func invariant(at keyPath: SBJValidationKeyPath) throws {
        try SBJInvariantCheck.require(hasContent, at: keyPath, "content required")
    }
}

private struct IdentityBased: Equatable, Encodable, SBJStructuralComparable {
    let identity: Int
    let payload: String
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.identity == rhs.identity }
    func sbjStructuralEquals(_ other: Self) -> Bool { payload == other.payload }
}

struct DomainMeaningTests {
    @Test func contentCanDifferFromContainerEmptiness() {
        let list = [DomainValue(text: "   ")]
        #expect(!list.isEmpty)
        #expect(!list.hasContent)
        #expect([DomainValue(text: "word")].hasContent)
    }

    @Test func invariantsUseMeaningfulPaths() {
        let value = DomainValue(text: " ")
        #expect(throws: SBJValidationError.self) {
            try value.invariant(at: .root.appending(\DomainValue.text))
        }
    }

    @Test func structuralComparisonIsIndependentOfApplicationEquality() {
        let left = IdentityBased(identity: 1, payload: "A")
        let right = IdentityBased(identity: 1, payload: "B")
        #expect(left == right)
        #expect(!SBJStructuralCompare.equals(left, right))
    }
}
