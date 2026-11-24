import Testing
@testable import SBJStructuredEditor

@Suite("Accessibility and localization regression contract")
struct SBJAccessibilityLocalizationRegressionTests {
    @Test func spokenFieldStatePreservesEveryStructuralCue() {
        #expect(SBJEditorAccessibilitySemantics.spokenLabel(
            label: "Servings", isChanged: false, hasContent: true, isInvalid: false
        ) == "Servings")

        #expect(SBJEditorAccessibilitySemantics.spokenLabel(
            label: "Servings", isChanged: true, hasContent: true, isInvalid: false
        ) == "Servings, changed")

        #expect(SBJEditorAccessibilitySemantics.spokenLabel(
            label: "Notes", isChanged: false, hasContent: false, isInvalid: false
        ) == "Notes, no content")

        #expect(SBJEditorAccessibilitySemantics.spokenLabel(
            label: "Servings", isChanged: true, hasContent: false, isInvalid: true
        ) == "Servings, changed, no content, invalid")
    }

    @Test func itemIdentitySurvivesPositionChange() {
        let parent = SBJEditTraversalContext.root.descended(property: "Ingredients")
        let before = parent.descended(stableIdentifier: "ingredient-42", index: 0)
        let after = parent.descended(stableIdentifier: "ingredient-42", index: 4)

        #expect(before.itemIdentifier == after.itemIdentifier)
        #expect(before.indexPath != after.indexPath)
        #expect(before.treeLevel == after.treeLevel)
    }

    @Test func distinctItemsNeverShareIdentityAtSamePosition() {
        let parent = SBJEditTraversalContext.root.descended(property: "Ingredients")
        let first = parent.descended(stableIdentifier: "ingredient-1", index: 0)
        let replacement = parent.descended(stableIdentifier: "ingredient-2", index: 0)

        #expect(first.itemIdentifier != replacement.itemIdentifier)
        #expect(first.indexPath == replacement.indexPath)
    }

}
