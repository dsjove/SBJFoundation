import SBJUIVocabulary
import Testing
import SBJDataDefinition
@testable import SBJFoundation

struct SBJEditorNavigationTests {
    @Test func issuePathsNormalizeAcrossCapabilityAndValidationSeparators() {
        let capability = SBJEditorNavigationTarget(issuePath: "Ingredients • [2] • Quantity")
        let validation = SBJEditorNavigationTarget(issuePath: "Ingredients › [2] › Quantity")

        #expect(capability == validation)
        #expect(capability.components == ["ingredients", "2", "quantity"])
    }

    @Test func navigationTargetRecognizesAncestorDisclosurePaths() {
        let target = SBJEditorNavigationTarget(issuePath: "Ingredients › Red bell pepper › Quantity")

        #expect(target.contains(["Ingredients"]))
        #expect(target.contains(["Ingredients", "Red bell pepper"]))
        #expect(target.contains(["Ingredients", "Red bell pepper", "Quantity"]))
        #expect(!target.contains(["Steps"]))
    }

    @Test func navigationTargetDistinguishesDestinationFromDisclosureAncestors() {
        let target = SBJEditorNavigationTarget(issuePath: "Ingredients › Red bell pepper › Quantity")

        #expect(target.isDescendant(of: ["Ingredients"]))
        #expect(target.isDescendant(of: ["Ingredients", "Red bell pepper"]))
        #expect(!target.isDescendant(of: ["Ingredients", "Red bell pepper", "Quantity"]))
        #expect(!target.isDescendant(of: ["Steps"]))
    }

    @MainActor @Test func navigationRequestsCanRepeatForTheSameProperty() {
        let state = SBJEditorPresentationModel()
        let target = SBJEditorNavigationTarget(issuePath: "Nutrition › Protein Grams")

        state.navigate(to: target)
        let firstRevision = state.navigationRevision
        state.navigate(to: target)

        #expect(state.navigationTarget == target)
        #expect(state.navigationRevision == firstRevision + 1)
    }

    @Test func traversalContextCarriesPresentationNavigationPath() {
        let root = SBJEditTraversalContext.root.property("Ingredients")
        let item = root.descended(stableIdentifier: "ingredient-id", index: 3)
        let child = item.property("Quantity")

        #expect(root.navigationPath == ["Ingredients"])
        #expect(item.navigationPath == ["Ingredients", "[3]"])
        #expect(child.navigationPath == ["Ingredients", "[3]", "Quantity"])
    }
}
