import CoreGraphics
import Foundation

/// Canonical integration/sample model for SBJStructure.
///
/// This model is intentionally broader than a normal application model. It is
/// shared by the structured-editor previews, the standalone `SBJEditField`
/// preview, and SBJStructure integration tests so those surfaces exercise the
/// same annotations, metadata, recursive editing, validation, comparison, and
/// Swift-source-export behavior.
enum SBJStructureSampleCourse: String, Codable, CaseIterable, Hashable {
  case breakfast
  case lunch
  case dinner
  case dessert
}

enum SBJStructureSampleIngredientUnit: String, Codable, CaseIterable, Hashable {
  case gram
  case kilogram
  case milliliter
  case liter
  case teaspoon
  case tablespoon
  case cup
  case item
}

@SBJStructure
enum SBJStructureSampleHeatSetting: Codable {
  case none
  case oven(celsius: Int, convection: Bool)
  case burner(level: Int)
}

struct SBJStructureSampleRating: Codable, Equatable {
  var value: Int
}

@SBJStructure
struct SBJStructureSampleNutrition: Codable {
  @SBJInteger(range: 0...2_500)
  var caloriesPerServing: Int

  @SBJNumber(range: 0...200)
  var proteinGrams: Double

  @SBJDesignatedInit
  init(caloriesPerServing: Int = 420, proteinGrams: Double = 14.5) {
    self.caloriesPerServing = caloriesPerServing
    self.proteinGrams = proteinGrams
  }
}

@SBJStructure
struct SBJStructureSampleIngredient: Codable, Hashable {
  var id = UUID()

  @SBJString(minLength: 1, maxLength: 60)
  var name = "New ingredient"

  @SBJNumber(range: 0...2_000)
  var quantity: Decimal = 1

  var unit: SBJStructureSampleIngredientUnit = .item

  @SBJString(maxLength: 80)
  var preparation: String? = nil
}

@SBJStructure
struct SBJStructureSampleStep: Codable, Hashable {
  var id = UUID()

  @SBJString(minLength: 1, maxLength: 50)
  var title = "New step"

  @SBJString(.multiline, minLength: 1, maxLength: 600)
  var instruction = "Describe what to do."
}

@SBJStructure
struct SBJStructureSampleModel: Codable {
  @SBJString(minLength: 1, maxLength: 80)
  var name = "Roasted Vegetable Pasta"

  @SBJString(.multiline, minLength: 1, maxLength: 400)
  var summary =
    "Roasted peppers, cauliflower, and onion tossed with pasta and a simple olive-oil dressing."

  @SBJInteger(range: 1...24)
  var servings = 4

  @SBJInteger(range: 0...480)
  var preparationMinutes = 20

  @SBJInteger(range: 0...720)
  var cookingMinutes = 35

  var course: SBJStructureSampleCourse = .dinner
  var vegetarian = true
  var rating = SBJStructureSampleRating(value: 4)

  @SBJUnitValue(min: 0)
  var servingVolume = UnitValue<VolumeUnit>(1.5, unit: .cup)
  var packageWeight = UnitValue<MassUnit>(340, unit: .gram)
  var simmerTime = UnitValue<DurationUnit>(45, unit: .minute)
  var panDepth: UnitValue<LengthUnit>? = .init(2, unit: .inch)

  @SBJDate(range: Date(timeIntervalSince1970: 0)...Date(timeIntervalSince1970: 4_102_444_800))
  var lastMade: Date? = Date()

  @SBJOptional(required: true)
  @SBJURL(allowed: [.network])
  var sourceURL: URL? = URL(string: "https://example.com/roasted-vegetable-pasta")

  @SBJData(min: 4, max: 16, modulo: 4)
  var importFingerprint = Data([0x52, 0x43, 0x50, 0x45])

  @SBJColor(alpha: false)
  var recipeCardTint = CodableColor(0.85, 0.35, 0.15, 1.0)

  @SBJPresentation(.fontFamily)
  var recipeCardFontFamily: String? = nil

  var nutrition = SBJStructureSampleNutrition()
  var heatSetting: SBJStructureSampleHeatSetting = .oven(celsius: 220, convection: true)

  @SBJArray(
    reorderable: true,
    title: \SBJStructureSampleIngredient.name,
    minCount: 1,
    maxCount: 30,
    uniqueBy: \SBJStructureSampleIngredient.id
  )
  var ingredients = [
    SBJStructureSampleIngredient(
      name: "Red bell pepper", quantity: 2, unit: .item, preparation: "sliced"),
    SBJStructureSampleIngredient(
      name: "Cauliflower", quantity: 500, unit: .gram, preparation: "cut into florets"),
    SBJStructureSampleIngredient(
      name: "Yellow onion", quantity: 1, unit: .item, preparation: "sliced"),
    SBJStructureSampleIngredient(name: "Olive oil", quantity: 2.5, unit: .tablespoon),
    SBJStructureSampleIngredient(name: "Pasta", quantity: 340, unit: .gram),
  ]

  @SBJArray(
    reorderable: true,
    title: \SBJStructureSampleStep.title,
    minCount: 1,
    maxCount: 20,
    uniqueBy: \SBJStructureSampleStep.id
  )
  var steps = [
    SBJStructureSampleStep(
      title: "Roast the vegetables",
      instruction:
        "Roast the peppers, cauliflower, and onion until browned at the edges and tender."
    ),
    SBJStructureSampleStep(
      title: "Cook the pasta",
      instruction: "Cook the pasta until al dente, reserving a little cooking water."
    ),
    SBJStructureSampleStep(
      title: "Combine",
      instruction:
        "Toss the pasta and roasted vegetables with olive oil. Add reserved cooking water as needed."
    ),
  ]

  @SBJSet(minCount: 1, maxCount: 12)
  var tags: Set<String> = ["Weeknight", "Vegetarian", "Roasted"]

  @SBJDictionary(maxCount: 12)
  var substitutions: [String: String] = [
    "Red bell pepper": "Orange bell pepper",
    "Pasta": "Whole-wheat pasta",
  ]

  @SBJString(.sheetEdit, maxLength: 1_000)
  var notes: String? = "Add red-pepper flakes at the table for anyone who wants more heat."

  @SBJEditorProperty
  var editorDisplayName: String {
    get { name }
    set { name = newValue }
  }

  @SBJUUID(nonzero: true)
  var identifier = UUID()

  @SBJNotEditable
  var importSource = "Canonical SBJStructure sample fixture"

  // MARK: - Standalone editor dispatch coverage

  // These are deliberately excluded from automatic editing so the primary
  // structured preview remains readable. `SBJEditFieldPreview` binds to them
  // directly to cover stock editor selection paths that a recipe would not
  // naturally need.

  @SBJNotEditable var editorSheetText = "This string uses the sheet-edit presentation."
  @SBJNotEditable var editorInt8: Int8 = 8
  @SBJNotEditable var editorInt16: Int16 = 16
  @SBJNotEditable var editorInt32: Int32 = 32
  @SBJNotEditable var editorInt64: Int64 = 64
  @SBJNotEditable var editorUInt: UInt = 1
  @SBJNotEditable var editorUInt8: UInt8 = 8
  @SBJNotEditable var editorUInt16: UInt16 = 16
  @SBJNotEditable var editorUInt32: UInt32 = 32
  @SBJNotEditable var editorUInt64: UInt64 = 64
  @SBJNotEditable var editorFloat: Float = 2.5
  @SBJNotEditable var editorCGFloat: CGFloat = 1.25
  @SBJNotEditable var editorDecimal: Decimal = 12.34
  @SBJNotEditable var editorDate = Date()
  @SBJNotEditable var editorURL = URL(string: "https://example.com")!

  static func propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
    switch keyPath as AnyKeyPath {
    case \Self.servings:
      return SBJPropertyInfo(
        title: "Servings",
        summary: "The number of portions the recipe is intended to make.",
        details:
          "The structural constraint is 1 through 24. The editor uses that domain knowledge to keep this numeric field compact without fixing it to one point size.",
        accessibilityLabel: "Recipe servings",
        accessibilityHint: "Enter the number of portions this recipe makes"
      )
    case \Self.lastMade:
      return SBJPropertyInfo(
        summary: "Optional date of the most recent preparation.",
        details: "The system date editor follows the user's locale and calendar preferences."
      )
    default:
      return nil
    }
  }
}
