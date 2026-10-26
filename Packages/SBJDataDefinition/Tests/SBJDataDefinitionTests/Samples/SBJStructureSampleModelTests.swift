#if DEBUG
import Testing
@testable import SBJDataDefinition


struct SBJStructureSampleModelTests {
  @Test func canonicalSampleProvidesRepresentativeStructuralMetadata() {
    let servings = SBJStructureSampleModel.propertyMetadata(for: \SBJStructureSampleModel.servings)
    #expect(servings?.constraints == [.integerRange(1...24)])

    let ingredients = SBJStructureSampleModel.propertyMetadata(
      for: \SBJStructureSampleModel.ingredients)
    #expect(ingredients?.kind == .array)
    #expect(ingredients?.constraints.contains(.reorderable(true)) == true)

    let sourceURL = SBJStructureSampleModel.propertyMetadata(
      for: \SBJStructureSampleModel.sourceURL)
    #expect(sourceURL?.kind == .optional)
  }

  @Test func samplePropertyInfoUsesCustomExtensionAndStructuralFallback() {
    #expect(SBJStructureSampleModel.propertyInfo(for: \SBJStructureSampleModel.preparationMinutes)
      == SBJStructureSampleModel.customPreparationMetadata)
    #expect(SBJStructureSampleModel.propertyInfo(for: \SBJStructureSampleModel.servings)
      == SBJStructureSampleModel.servingsInfo)
    #expect(SBJStructureSampleModel.propertyInfo(for: \SBJStructureSampleModel.lastMade)
      == SBJStructureSampleModel.lastMadeInfo)
    #expect(SBJStructureSampleModel.propertyInfo(for: \SBJStructureSampleModel.name)
      == SBJStructureSampleModel._propertyInfo(for: \SBJStructureSampleModel.name))
  }


  @Test func extensionPropertyInfoFlowsIntoStructuralMetadata() {
    let servings = SBJStructureSampleModel.propertyMetadata(for: \SBJStructureSampleModel.servings)
    #expect(servings?.info == SBJStructureSampleModel.servingsInfo)
    let preparation = SBJStructureSampleModel.propertyMetadata(for: \SBJStructureSampleModel.preparationMinutes)
    #expect(preparation?.info == SBJStructureSampleModel.customPreparationMetadata)
  }

  @Test func enumExtensionPropertyInfoUsesCaseNames() {
    #expect(SBJStructureSampleCookingInstruction.sbjCaseInfo(for: "oven")
      == SBJStructureSampleCookingInstruction.ovenInfo)
    #expect(SBJStructureSampleCookingInstruction.sbjCaseInfo(for: "missing") == nil)
  }

  @Test func canonicalSampleExercisesValidationAndStructuralComparison() {
    let original = SBJStructureSampleModel()
    var changed = original
    changed.servings = 0

    #expect(!original.sbjStructuralEquals(changed))
    #expect(throws: SBJValidationError.self) {
      try changed.invariant(at: \SBJStructureSampleModel.self)
    }
  }

  @Test func canonicalSampleExercisesSwiftSourceExport() {
    let source = SBJSwiftEncoder().encode(SBJStructureSampleModel(), named: "sample")
    #expect(source.contains("sample"))
    #expect(source.contains("Roasted Vegetable Pasta"))
  }
}

/// Compile-time integration guards: generic constraints fail when the recipe
/// stops generating mutable structure / enum metadata.
struct SBJRecipeCompileTimeContractTests {
  private func acceptsMutableStructure<T: SBJMutableStructure>(_ type: T.Type) {}
  private func acceptsStructuredEnum<T: SBJStructuredEnum>(_ type: T.Type) {}

  @Test func recipeTypesCompileWithGeneratedStructureContracts() {
    acceptsMutableStructure(SBJStructureSampleModel.self)
    acceptsMutableStructure(SBJStructureSampleNutrition.self)
    acceptsMutableStructure(SBJStructureSampleIngredient.self)
    acceptsMutableStructure(SBJStructureSampleStep.self)
    acceptsMutableStructure(SBJStructureSampleCookingStage.self)
    acceptsStructuredEnum(SBJStructureSampleCookingInstruction.self)
    acceptsStructuredEnum(SBJStructureSampleCookingPlan.self)
    acceptsStructuredEnum(SBJStructureSampleHeatSetting.self)
  }

  @Test func recipeCasesCoverNoUnlabeledLabeledOptionalAndCollections() {
    let cases = SBJStructureSampleCookingInstruction.sbjAssociatedCases
    #expect(cases.count == 4)
    let recipe = SBJStructureSampleModel()
    #expect(recipe.cookingInstructionArray.count == 2)
    #expect(recipe.absentCookingInstruction == nil)
    #expect(recipe.noCookingInstruction == nil)
    #expect(recipe.cookingStages.count == 2)
  }
}

#endif
