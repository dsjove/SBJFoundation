#if DEBUG
import CoreGraphics
import Foundation
import SBJLocalization

/// Canonical integration/sample model for SBJStructure.
///
/// This model is intentionally broader than a normal application model. It is
/// shared by the structured-editor previews, the standalone `SBJEditField`
/// preview, and SBJStructure integration tests so those surfaces exercise the
/// same annotations, metadata, recursive editing, validation, comparison, and
/// Swift-source-export behavior.
/// Shared documentation for every Recipe property whose value is a course.
public enum SBJStructureSampleCourse: String, Codable, CaseIterable, Hashable, SBJDefinitionTypeInfoProviding {
  public static let definitionTypeInfo = SBJPropertyInfo(
    title: "Course",
    summary: "The meal category for a recipe.",
    details: "Breakfast, lunch, dinner, or dessert.",
    accessibilityHint: "Choose the meal category"
  )

  case breakfast
  case lunch
  case dinner
  case dessert
}

public enum SBJStructureSampleIngredientUnit: String, Codable, CaseIterable, Hashable {
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
public enum SBJStructureSampleHeatSetting: Codable {
  case oven(celsius: Int, convection: Bool)
  case burner(level: Int)
}

/// Recipe-specific stress coverage for associated-value case editing.
/// Includes unlabeled payload, heterogeneous labeled payloads,
/// optional values, and collection payloads.
@SBJStructure
public enum SBJStructureSampleCookingInstruction: Codable {
  case adjustTemperature(Int)
  case oven(temperature: Int, convection: Bool, explanation: String)
  case rest(start: Date, finish: Date, notes: String?)
  case substitutions(quantities: [Int], alternatives: [String: String], allergens: Set<String>)
}

@SBJPropertyInfoEnum
extension SBJStructureSampleCookingInstruction {
  public static let adjustTemperatureInfo = SBJPropertyInfo(title: "Temperature adjustment")
  public static let ovenInfo = SBJPropertyInfo(title: "Oven settings")
  public static let restInfo = SBJPropertyInfo(title: "Resting interval")
  public static let substitutionsInfo = SBJPropertyInfo(title: "Ingredient substitutions")
}

@SBJStructure
public enum SBJStructureSampleCookingPlan: Codable {
  case direct(SBJStructureSampleCookingInstruction)
  case alternatives(primary: SBJStructureSampleCookingInstruction, backup: SBJStructureSampleCookingInstruction?)
}

@SBJStructure
public struct SBJStructureSampleCookingStage: Codable {
  public init() {}
  public var title = "Roast vegetables"
  public var instruction: SBJStructureSampleCookingInstruction = .adjustTemperature(5)
  public var optionalInstruction: SBJStructureSampleCookingInstruction? = .oven(
    temperature: 220, convection: true, explanation: "Use the middle rack")
}

public struct SBJStructureSampleRating: Codable, Equatable {
  public init(value: Int) { self.value = value }
  public var value: Int
}

@SBJStructure
public struct SBJStructureSampleNutrition: Codable {
  @SBJInteger(range: 0...2_500)
  public var caloriesPerServing: Int

  @SBJNumber(range: 0...200)
  public var proteinGrams: Double

  @SBJDesignatedInit
  public init(caloriesPerServing: Int = 420, proteinGrams: Double = 14.5) {
	self.caloriesPerServing = caloriesPerServing
	self.proteinGrams = proteinGrams
  }
}

@SBJStructure
public struct SBJStructureSampleIngredient: Codable, Hashable {
  public init(name: String = "New ingredient", quantity: Decimal = 1, unit: SBJStructureSampleIngredientUnit = .item, preparation: String? = nil) {
    self.name = name
    self.quantity = quantity
    self.unit = unit
    self.preparation = preparation
  }
  public var id = UUID()

  @SBJString(minLength: 1, maxLength: 60)
  public var name = "New ingredient"

  @SBJNumber(range: 0...2_000)
  public var quantity: Decimal = 1

  public var unit: SBJStructureSampleIngredientUnit = .item

  @SBJString(maxLength: 80)
  public var preparation: String? = nil
}

@SBJStructure
public struct SBJStructureSampleStep: Codable, Hashable {
  public init(title: String = "New step", instruction: String = "Describe what to do.") {
    self.title = title
    self.instruction = instruction
  }
  public var id = UUID()

  @SBJString(minLength: 1, maxLength: 50)
  public var title = "New step"

  @SBJString(minLength: 1, maxLength: 600)
  @SBJStringPresentation(.multiline)
  public var instruction = "Describe what to do."
}

@SBJStructure
public struct SBJStructureSampleModel: Codable {
  public init() {}
  @SBJString(minLength: 1, maxLength: 80)
  public var name = "Roasted Vegetable Pasta"

  @SBJString(minLength: 1, maxLength: 400)
  @SBJStringPresentation(.multiline)
  public var summary =
	"Roasted peppers, cauliflower, and onion tossed with pasta and a simple olive-oil dressing."

  @SBJInteger(range: 1...24)
  public var servings = 4

  @SBJInteger(range: 0...480)
  public var preparationMinutes = 20

  @SBJInteger(range: 0...720)
  public var cookingMinutes = 35

  public var course: SBJStructureSampleCourse = .dinner
  public var vegetarian = true
  public var rating = SBJStructureSampleRating(value: 4)

  @SBJUnitValue(min: 0, unitMutable: true)
  public var servingVolume = UnitValue<VolumeUnit>(1.5, unit: .cup)
  @SBJUnitValue(unitMutable: false)
  public var packageWeight = UnitValue<MassUnit>(340, unit: .gram)
  public var simmerTime = UnitValue<DurationUnit>(45, unit: .minute)
  public var panDepth: UnitValue<LengthUnit>? = .init(2, unit: .inch)

  @SBJDate(range: Date(timeIntervalSince1970: 0)...Date(timeIntervalSince1970: 4_102_444_800))
  public var lastMade: Date? = Date()

  @SBJOptional(required: true)
  @SBJURL(allowed: [.network])
  public var sourceURL: URL? = URL(string: "https://example.com/roasted-vegetable-pasta")

  @SBJData(min: 4, max: 16, modulo: 4)
  public var importFingerprint = Data([0x52, 0x43, 0x50, 0x45])

  @SBJColorPresentation(alpha: false)
  public var recipeCardTint = CodableColor(0.85, 0.35, 0.15, 1.0)

  public var recipeCardFontFamily: FontFamily? = nil
  public var recipeCardFont = CodableFont(nil, ofSize: 14)
  public var preferredVolumeSteps = UnitEditingPolicy<VolumeUnit>(defaultStep: 0.25)
  public var preferredMeasurementSystem: MeasurementSystem = .metric

  @SBJFieldPresentation(autoExpand: false)
  public var nutrition = SBJStructureSampleNutrition()
  public var heatSetting: SBJStructureSampleHeatSetting = .oven(celsius: 220, convection: true)

  // MARK: - Recipe-domain stress scenarios
  // These replace the former standalone enum stress model. Repeated cases
  // specifically test independent binding and payload reconstruction.
  public var noCookingInstruction: SBJStructureSampleCookingInstruction? = nil
  public var temperatureAdjustment: SBJStructureSampleCookingInstruction = .adjustTemperature(-5)
  public var ovenInstruction: SBJStructureSampleCookingInstruction = .oven(
    temperature: 220, convection: true, explanation: "Roast until browned\nTurn halfway")
  public var restingInstruction: SBJStructureSampleCookingInstruction = .rest(
    start: Date(timeIntervalSince1970: 1_700_000_000),
    finish: Date(timeIntervalSince1970: 1_700_000_900), notes: nil)
  public var substitutionsInstruction: SBJStructureSampleCookingInstruction = .substitutions(
    quantities: [1, 2, 3],
    alternatives: ["pepper": "carrot", "pasta": "rice"],
    allergens: ["wheat", "nuts"])
  public var optionalCookingInstruction: SBJStructureSampleCookingInstruction? = .adjustTemperature(10)
  public var absentCookingInstruction: SBJStructureSampleCookingInstruction? = nil
  public var cookingInstructionArray: [SBJStructureSampleCookingInstruction] = [.adjustTemperature(3), .oven(temperature: 180, convection: false, explanation: "Gentle heat")]
  public var cookingInstructionDictionary: [String: SBJStructureSampleCookingInstruction] = [
    "vegetables": .adjustTemperature(5)]
  public var cookingPlan: SBJStructureSampleCookingPlan = .alternatives(
    primary: .adjustTemperature(8), backup: nil)
  public var cookingStage: SBJStructureSampleCookingStage = .init()
  @SBJFieldPresentation(autoExpand: true)
  public var cookingStages: [SBJStructureSampleCookingStage] = [.init(), .init()]
  public var optionalCourse: SBJStructureSampleCourse? = nil
  public var optionalServings: Int? = 4
  public var optionalChefNote: String? = nil

  @SBJArray(minCount: 1, maxCount: 30, uniqueBy: \SBJStructureSampleIngredient.id)
  @SBJArrayPresentation(title: \SBJStructureSampleIngredient.name, reorderable: true)
  public var ingredients = [
	SBJStructureSampleIngredient(
	  name: "Red bell pepper", quantity: 2, unit: .item, preparation: "sliced"),
	SBJStructureSampleIngredient(
	  name: "Cauliflower", quantity: 500, unit: .gram, preparation: "cut into florets"),
	SBJStructureSampleIngredient(
	  name: "Yellow onion", quantity: 1, unit: .item, preparation: "sliced"),
	SBJStructureSampleIngredient(name: "Olive oil", quantity: 2.5, unit: .tablespoon),
	SBJStructureSampleIngredient(name: "Pasta", quantity: 340, unit: .gram),
  ]

  @SBJArray(minCount: 1, maxCount: 20, uniqueBy: \SBJStructureSampleStep.id)
  @SBJArrayPresentation(title: \SBJStructureSampleStep.title, reorderable: true)
  public var steps = [
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
  @SBJSetPresentation()
  public var tags: Set<String> = ["Weeknight", "Vegetarian", "Roasted"]

  @SBJDictionary(maxCount: 12)
  public var substitutions: [String: String] = [
	"Red bell pepper": "Orange bell pepper",
	"Pasta": "Whole-wheat pasta",
  ]

  @SBJString(maxLength: 1_000)
  @SBJStringPresentation(.sheetEdit)
  public var notes: String? = "Add red-pepper flakes at the table for anyone who wants more heat."

  @SBJFieldPresentation()
  public var editorDisplayName: String {
	get { name }
	set { name = newValue }
  }

  @SBJUUID(nonzero: true)
  public var identifier = UUID()

  @SBJFieldPresentation(exclude: true)
  public var importSource = "Canonical SBJStructure sample fixture"

  // MARK: - Standalone editor dispatch coverage

  // These are deliberately excluded from automatic editing so the primary
  // structured preview remains readable. `SBJEditFieldPreview` binds to them
  // directly to cover stock editor selection paths that a recipe would not
  // naturally need.

  @SBJFieldPresentation(exclude: true) public var editorSheetText = "This string uses the sheet-edit presentation."
  @SBJFieldPresentation(exclude: true) public var editorInt8: Int8 = 8
  @SBJFieldPresentation(exclude: true) public var editorInt16: Int16 = 16
  @SBJFieldPresentation(exclude: true) public var editorInt32: Int32 = 32
  @SBJFieldPresentation(exclude: true) public var editorInt64: Int64 = 64
  @SBJFieldPresentation(exclude: true) public var editorUInt: UInt = 1
  @SBJFieldPresentation(exclude: true) public var editorUInt8: UInt8 = 8
  @SBJFieldPresentation(exclude: true) public var editorUInt16: UInt16 = 16
  @SBJFieldPresentation(exclude: true) public var editorUInt32: UInt32 = 32
  @SBJFieldPresentation(exclude: true) public var editorUInt64: UInt64 = 64
  @SBJFieldPresentation(exclude: true) public var editorFloat: Float = 2.5
  @SBJFieldPresentation(exclude: true) public var editorCGFloat: CGFloat = 1.25
  @SBJFieldPresentation(exclude: true) public var editorDecimal: Decimal = 12.34
  @SBJFieldPresentation(exclude: true) public var editorDate = Date()
  @SBJFieldPresentation(exclude: true) public var editorURL = URL(string: "https://example.com")!
}

#endif
