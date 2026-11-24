import Testing
@testable import SBJLocalization

struct SBJNomenclatureTitleTests {
    @Test func omittedTitleIsEmptyInsteadOfOptional() {
        let value = SBJNomenclature(summary: "Description")
        #expect(value.title.isEmpty)
        #expect(value.nonEmptyTitle == nil)
        #expect(value.accessibility.accessibilityLabel == nil)
    }

    @Test func explicitTitleProvidesAccessibilityDefault() {
        let value = SBJNomenclature(title: "HP", summary: "Current health")
        #expect(value.title == "HP")
        #expect(value.nonEmptyTitle == "HP")
        #expect(value.accessibility.accessibilityLabel == "HP")
    }

    @Test func untitledNomenclatureMayStillSupplyAccessibility() {
        let value = SBJNomenclature(accessibilityLabel: "Choose a portrait")
        #expect(value.nonEmptyTitle == nil)
        #expect(value.accessibility.accessibilityLabel == "Choose a portrait")
    }

    @Test func whitespaceIsNotAnEmptyTitle() {
        let value = SBJNomenclature(title: " ")
        #expect(value.nonEmptyTitle == " ")
    }

}
