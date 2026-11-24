import Testing
@testable import SBJStructure

private enum TestIssueKind: Hashable {
    case validation
    case unsupported
}

struct SBJIssueTests {
    private func issue(
        _ path: String,
        message: String = "child failed",
        kind: TestIssueKind = .validation
    ) -> SBJIssue<TestIssueKind> {
        .init(
            kind: kind,
            path: path,
            typeName: kind == .validation ? "Validation" : "Unsupported",
            valueDescription: message
        )
    }

    @Test func redundantAncestorIssueIsRemovedInFavorOfChild() {
        let parent = issue("Character • Weapon")
        let child = issue("Character • Weapon • Damage")

        let result = SBJIssue<TestIssueKind>.removingRedundantIssues(from: [parent, child])

        #expect(result == [child])
    }

    @Test func structurallyWrappedRootIssueIsRemovedInFavorOfDirectChildPath() {
        let root = issue("\\Character.self.\\Character.weapon.\\Weapon.damage")
        let direct = issue("\\Character.weapon.\\Weapon.damage")

        let result = SBJIssue<TestIssueKind>.removingRedundantIssues(from: [root, direct])

        #expect(result == [direct])
    }

    @Test func samePathDuplicateKeepsFirstOccurrence() {
        let first = issue("Character • Name")
        let duplicate = issue("Character • Name")

        let result = SBJIssue<TestIssueKind>.removingRedundantIssues(from: [first, duplicate])

        #expect(result.count == 1)
        #expect(result.first == first)
    }

    @Test func parentAndChildWithDifferentMessagesAreBothRetained() {
        let parent = issue("Character • Weapon", message: "weapon configuration is invalid")
        let child = issue("Character • Weapon • Damage", message: "damage must be positive")

        let result = SBJIssue<TestIssueKind>.removingRedundantIssues(from: [parent, child])

        #expect(result == [parent, child])
    }

    @Test func unrelatedPathsWithSameMessageAreBothRetained() {
        let first = issue("Character • Strength")
        let second = issue("Character • Dexterity")

        let result = SBJIssue<TestIssueKind>.removingRedundantIssues(from: [first, second])

        #expect(result == [first, second])
    }

    @Test func differentKindsAreNeverCollapsed() {
        let validation = issue("Character • Weapon", kind: .validation)
        let unsupported = issue("Character • Weapon • Damage", kind: .unsupported)

        let result = SBJIssue<TestIssueKind>.removingRedundantIssues(from: [validation, unsupported])

        #expect(result == [validation, unsupported])
    }
}

extension SBJIssueTests {
    @Test func distinctMessagesAtSamePathHaveDistinctIdentity() {
        let first = issue("Character • Name", message: "must not be empty")
        let second = issue("Character • Name", message: "must be unique")

        #expect(first.id != second.id)
        #expect(SBJIssue<TestIssueKind>.removingRedundantIssues(from: [first, second]) == [first, second])
    }
}
