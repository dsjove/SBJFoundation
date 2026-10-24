import Testing
@testable import SBJDataDefinition

@Suite struct SBJArrayMutationTests {
    @Test func movesAndBoundaries() {
        var values = ["first", "second", "third"]
        #expect(SBJArrayMutation.move(from: 0, to: 1, in: &values))
        #expect(values == ["second", "first", "third"])
        #expect(!SBJArrayMutation.move(from: 0, to: -1, in: &values))
        #expect(!SBJArrayMutation.move(from: 2, to: 3, in: &values))
        #expect(!SBJArrayMutation.move(from: 1, to: 1, in: &values))
        #expect(values == ["second", "first", "third"])
    }
    @Test func duplicatesAndRemove() {
        var values = ["same", "same", "other"]
        #expect(SBJArrayMutation.move(from: 1, to: 2, in: &values))
        #expect(values == ["same", "other", "same"])
        #expect(SBJArrayMutation.remove(at: 1, from: &values))
        #expect(values == ["same", "same"])
        #expect(!SBJArrayMutation.remove(at: 2, from: &values))
    }
}
