import Testing
@testable import SBJLocalization

struct ArrayBulletedTests {
    @Test func prefixIsNotEmittedForEmptyElements() {
        #expect(["Alpha", "", "Beta"].bulleted(prefix: "- ") == "- Alpha • - Beta")
    }
}
