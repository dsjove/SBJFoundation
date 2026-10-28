import Testing
@testable import SBJDataDefinition

@SBJStructure
private struct SortedScores {
    @SBJArray(sorted: .ascending)
    var scores: [Int]
}

@SBJStructure
private struct DescendingScores {
    @SBJArray(sorted: .descending)
    var scores: [Int]
}

@Suite("Array sorted snapshot invariant")
struct SBJArraySortedInvariantTests {
    @Test func returnsFirstViolationWithoutSorting() {
        let values = [1, 2, 2, 7, 4, 3]
        #expect(values.firstOutOfOrderIndex(direction: .ascending) == 4)
        #expect(values == [1, 2, 2, 7, 4, 3])
        #expect([9, 8, 8, 3].firstOutOfOrderIndex(direction: .descending) == nil)
        #expect([9, 8, 10, 3].firstOutOfOrderIndex(direction: .descending) == 2)
    }

    @Test func generatedInvariantReportsViolationAtElement() {
        let ascending = SortedScores(scores: [2, 5, 4, 3])
        let descending = DescendingScores(scores: [10, 9, 11])
        #expect(SBJInvariantCheck.validationError(ascending, at: SBJValidationKeyPath.root) != nil)
        #expect(SBJInvariantCheck.validationError(descending, at: SBJValidationKeyPath.root) != nil)
        #expect(SBJInvariantCheck.validationError(SortedScores(scores: [1, 1, 2]), at: SBJValidationKeyPath.root) == nil)
    }
}
