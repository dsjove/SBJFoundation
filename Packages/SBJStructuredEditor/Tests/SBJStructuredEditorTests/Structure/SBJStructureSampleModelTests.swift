#if DEBUG
import Testing
@testable import SBJStructuredEditor
import SBJDataDefinition

/// Editor-owned contract: the canonical DataDefinition recipe is rendered by
/// the structural projection, rather than by generated editor macros.
struct SBJRecipeEditorProjectionTests {
    @MainActor
    @Test func recipeFieldsUseGeneratedPresentationMetadata() {
        let fields = SBJStructuralFieldProjection.fields(of: SBJStructureSampleModel.self)
        let names = fields.map(\.name)
        #expect(names.contains("Name"))
        #expect(names.contains("Editor Display Name"))
        #expect(!names.contains("Editor Int8"))
        #expect(!names.contains("Editor UInt64"))
        #expect(!names.contains("Editor Date"))
    }

    @MainActor
    @Test func recipeAssociatedEnumsAreProjectedThroughDefinitionCases() {
        let cases = SBJStructureSampleCookingInstruction.sbjAssociatedCases
        #expect(cases.map(\.sourceName) == ["adjustTemperature", "oven", "rest", "substitutions"])
        let recipe = SBJStructureSampleModel()
        #expect(recipe.noCookingInstruction == nil)
        #expect(recipe.cookingInstructionArray.count == 2)
        #expect(recipe.cookingStages.count == 2)
    }
}
#endif
