import Testing
@testable import SBJLocalization

struct SemanticNomenclatureTests {
    @Test func aliasesAreDistinctFromAccessibility() {
        let info = SBJNomenclature(title: "Hit Points", summary: "Health", aliases: ["HP", "health points"])
        #expect(info.aliases == ["HP", "health points"])
        #expect(info.accessibility.accessibilityLabel == "Hit Points")
    }

    @Test func defaultAliasesAreEmpty() {
        #expect(SBJNomenclature(title: "Strength").aliases.isEmpty)
    }
}
