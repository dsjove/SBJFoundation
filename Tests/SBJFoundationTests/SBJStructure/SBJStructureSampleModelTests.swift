import Testing

@testable import SBJFoundation

struct SBJStructureSampleModelTests {
  @Test func canonicalSampleProvidesRepresentativeStructuralMetadata() {
    let servings = SBJStructureSampleModel.propertyMetadata(for: \SBJStructureSampleModel.servings)
    #expect(servings?.constraints == [.integerRange(1...24)])

    let ingredients = SBJStructureSampleModel.propertyMetadata(
      for: \SBJStructureSampleModel.ingredients)
    #expect(ingredients?.kind == .array)
    #expect(ingredients?.hints.contains(.reorderable(true)) == true)

    let sourceURL = SBJStructureSampleModel.propertyMetadata(
      for: \SBJStructureSampleModel.sourceURL)
    #expect(sourceURL?.kind == .optional)
  }

  @MainActor
  @Test func canonicalSampleSeparatesAutomaticFieldsFromStandaloneDispatchCoverage() {
    let names = SBJStructureSampleModel.sbjEditorFields.map(\.name)

    #expect(names.contains("Name"))
    #expect(names.contains("Editor Display Name"))
    #expect(!names.contains("Editor Int8"))
    #expect(!names.contains("Editor UInt64"))
    #expect(!names.contains("Editor Date"))
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
