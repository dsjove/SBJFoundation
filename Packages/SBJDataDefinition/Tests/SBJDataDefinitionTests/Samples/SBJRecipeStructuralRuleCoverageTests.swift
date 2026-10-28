import Foundation
import Testing
@testable import SBJDataDefinition

// Focused edge-case fixtures complement the canonical Recipe integration model.
private struct RecipeRuleItem: Codable, Hashable {
    var id: Int
    var name: String
}

@SBJStructure
private struct RecipeRuleFixture: Codable {
    @SBJString(minLength: 1, maxLength: 8)
    @SBJStringPresentation(.multiline)
    var text: String = "a"

    @SBJInteger(range: 1...3)
    var integer: Int = 1

    @SBJNumber(range: 0...1)
    var number: Double = 0.5

    @SBJOptional(required: false)
    var optional: String?

    @SBJArray(minCount: 1, maxCount: 2, uniqueBy: \RecipeRuleItem.id)
    @SBJArrayPresentation(title: \RecipeRuleItem.name, reorderable: true)
    var array: [RecipeRuleItem] = [.init(id: 1, name: "one")]

    @SBJSet(minCount: 1, maxCount: 2)
    @SBJSetPresentation(title: \RecipeRuleItem.name)
    var set: Set<RecipeRuleItem> = [.init(id: 1, name: "one")]

    @SBJDictionary(minCount: 1, maxCount: 2)
    var dictionary: [String: Int] = ["one": 1]

    @SBJURL(allowed: [.network])
    var url = URL(string: "https://example.com")!

    @SBJUUID(nonzero: true)
    var uuid = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!

    @SBJDate(range: Date(timeIntervalSince1970: 0)...Date(timeIntervalSince1970: 100))
    var date = Date(timeIntervalSince1970: 0)

    @SBJData(min: 2, max: 4, modulo: 2)
    var data = Data([0x01, 0x02])

    @SBJColorPresentation(alpha: false)
    var color = CodableColor(1, 0, 0)
}


@SBJStructure
private struct RecipeCodingShapeFixture: Codable {
    var text: String = ""
    var enabled: Bool = false
    var count: Int = 0
    var ratio: Double = 0
    var date: Date = .distantPast
    var url: URL = URL(string: "https://example.com")!
    var uuid: UUID = UUID()
    var data: Data = Data()
    var color: CodableColor = CodableColor()
    var array: [String] = []
    var set: Set<String> = []
    var dictionary: [String: Int] = [:]
    var excluded: String = "not coded"

    enum CodingKeys: String, CodingKey {
        case text, enabled, count, ratio, date, url, uuid, data, color, array, set, dictionary
    }
}


struct SBJRecipeStructuralRuleCoverageTests {
    @Test func structuralMetadataCoversEveryCurrentAnnotationFamily() {
        let kinds = Dictionary(uniqueKeysWithValues: RecipeRuleFixture.sbjProperties.map { ($0.sourceName, $0.kind) })

        #expect(kinds["text"] == .text)
        #expect(kinds["integer"] == .integer)
        #expect(kinds["number"] == .number)
        #expect(kinds["optional"] == .optional)
        #expect(kinds["array"] == .array)
        #expect(kinds["set"] == .set)
        #expect(kinds["dictionary"] == .dictionary)
        #expect(kinds["url"] == .url)
        #expect(kinds["uuid"] == .uuid)
        #expect(kinds["date"] == .date)
        #expect(kinds["data"] == .data)
        #expect(kinds["color"] == .color)
    }

    @Test func currentRulesAndHintsAreRepresentedWithoutEnforcement() throws {
        let text = RecipeRuleFixture.propertyMetadata(for: \RecipeRuleFixture.text)
        #expect(text?.constraints == [.stringRules(SBJStringRules(minLength: 1, maxLength: 8))])
        #expect(text?.hints == [.stringPresentation(SBJStringPresentationValue(style: .multiline))])

        let optional = RecipeRuleFixture.propertyMetadata(for: \RecipeRuleFixture.optional)
        #expect(optional?.constraints == [.optionalRules(SBJOptionalRules(required: false))])

        let array = RecipeRuleFixture.propertyMetadata(for: \RecipeRuleFixture.array)
        #expect(array?.constraints == [.arrayRules(SBJArrayRules(minCount: 1, maxCount: 2)), .uniqueBy("\\RecipeRuleItem.id")])
        #expect(array?.hints.contains(.arrayPresentation(SBJArrayPresentationValue(reorderable: true))) == true && array?.hints.contains(.itemTitle("name")) == true)

        let set = RecipeRuleFixture.propertyMetadata(for: \RecipeRuleFixture.set)
        #expect(set?.constraints == [.setRules(SBJSetRules(minCount: 1, maxCount: 2))])
        #expect(set?.hints == [.setPresentation(SBJSetPresentationValue(insertable: true, removable: true)), .itemTitle("name")])

        let data = RecipeRuleFixture.propertyMetadata(for: \RecipeRuleFixture.data)
        #expect(data?.constraints == [.dataRules(SBJDataRules(min: 2, max: 4, modulo: 2))])

        let url = RecipeRuleFixture.propertyMetadata(for: \RecipeRuleFixture.url)
        #expect(url?.constraints == [.urlRules(SBJURLRules(allowed: [.network]))])

        let uuid = RecipeRuleFixture.propertyMetadata(for: \RecipeRuleFixture.uuid)
        #expect(uuid?.constraints == [.uuidRules(SBJUUIDRules(nonzero: true))])

        let date = RecipeRuleFixture.propertyMetadata(for: \RecipeRuleFixture.date)
        #expect(date?.constraints == [.dateRules(SBJDateRules(range: Date(timeIntervalSince1970: 0)...Date(timeIntervalSince1970: 100)))])

        let color = RecipeRuleFixture.propertyMetadata(for: \RecipeRuleFixture.color)
        #expect(color?.hints == [.colorPresentation(SBJColorPresentationValue(alpha: false))])

        var value = RecipeRuleFixture()
        value.integer = 100
        value.text = ""
        value.array = []
        value.data = Data([0x01])

        // Assignment/access remains ordinary Swift. Explicit validation is what rejects it.
        #expect(value.integer == 100)
        #expect(value.text.isEmpty)
        #expect(value.array.isEmpty)
        #expect(value.data.count == 1)
        #expect(throws: SBJValidationError.self) {
            try value.invariant(at: \RecipeRuleFixture.self)
        }
    }

    @Test func floatingPointValidationRejectsNonFiniteValues() {
        let path = SBJValidationKeyPath(\RecipeRuleFixture.number)
        #expect(throws: SBJValidationError.self) {
            try SBJInvariantCheck.requireRange(Double.nan, 0...1, at: path)
        }
        #expect(throws: SBJValidationError.self) {
            try SBJInvariantCheck.requireRange(Double.infinity, 0...1, at: path)
        }
    }

    @Test func dataConstraintBoundariesAreInclusiveAndModuloIsExplicit() throws {
        let path = SBJValidationKeyPath(\RecipeRuleFixture.data)
        try SBJInvariantCheck.requireData(Data(repeating: 0, count: 2), min: 2, max: 4, modulo: 2, at: path)
        try SBJInvariantCheck.requireData(Data(repeating: 0, count: 4), min: 2, max: 4, modulo: 2, at: path)

        #expect(throws: SBJValidationError.self) {
            try SBJInvariantCheck.requireData(Data(repeating: 0, count: 3), min: 2, max: 4, modulo: 2, at: path)
        }
        #expect(throws: SBJValidationError.self) {
            try SBJInvariantCheck.requireData(Data(), modulo: 0, at: path)
        }
    }

    @Test func urlKindsAreExplicitInvariantConstraints() throws {
        let path = SBJValidationKeyPath(\RecipeRuleFixture.url)
        try SBJInvariantCheck.requireURL(URL(string: "https://example.com")!, allowed: [.network], at: path)
        try SBJInvariantCheck.requireURL(URL(fileURLWithPath: "/tmp/example"), allowed: [.file], at: path)

        #expect(throws: SBJValidationError.self) {
            try SBJInvariantCheck.requireURL(URL(fileURLWithPath: "/tmp/example"), allowed: [.network], at: path)
        }
        #expect(throws: SBJValidationError.self) {
            try SBJInvariantCheck.requireURL(URL(string: "https://example.com")!, allowed: [.file], at: path)
        }
        #expect(throws: SBJValidationError.self) {
            try SBJInvariantCheck.requireURL(URL(string: "relative/path")!, allowed: [.network], at: path)
        }
    }

    @Test func annotatedURLStillAllowsInvalidStateUntilValidation() {
        var value = RecipeRuleFixture()
        value.url = URL(fileURLWithPath: "/tmp/local")
        #expect(value.url.isFileURL)
        #expect(throws: SBJValidationError.self) {
            try value.invariant(at: \RecipeRuleFixture.self)
        }
    }

    @Test func codingKeysDefineStructureAndAnnotationsAreNotRequiredForKinds() {
        let metadata = Dictionary(uniqueKeysWithValues: RecipeCodingShapeFixture.sbjProperties.map { ($0.sourceName, $0.kind) })
        #expect(metadata["text"] == .text)
        #expect(metadata["enabled"] == .bool)
        #expect(metadata["count"] == .integer)
        #expect(metadata["ratio"] == .number)
        #expect(metadata["date"] == .date)
        #expect(metadata["url"] == .url)
        #expect(metadata["uuid"] == .uuid)
        #expect(metadata["data"] == .data)
        #expect(metadata["color"] == .color)
        #expect(metadata["array"] == .array)
        #expect(metadata["set"] == .set)
        #expect(metadata["dictionary"] == .dictionary)
        #expect(metadata["excluded"] == nil)
    }

    @Test func uuidZeroHelpersArePublicAndValidationIsExplicit() throws {
        #expect(UUID.sbjZero.sbjIsZero)
        #expect(!UUID().sbjIsZero)

        let path = SBJValidationKeyPath(\RecipeRuleFixture.uuid)
        #expect(throws: SBJValidationError.self) {
            try SBJInvariantCheck.requireNonzero(.sbjZero, at: path)
        }
        try SBJInvariantCheck.requireNonzero(UUID(), at: path)
    }
    @Test func recipeAssociatedCaseStressCoverageHasNoAbsenceCase() {
        let cases = SBJStructureSampleCookingInstruction.sbjAssociatedCases
        #expect(cases.map(\.sourceName) == ["adjustTemperature", "oven", "rest", "substitutions"])
        #expect(!cases.map(\.sourceName).contains("none"))
        #expect(cases[0].associatedValues.count == 1)
        #expect(cases[1].associatedValues.count == 3)
        #expect(cases[2].associatedValues.count == 3)
        #expect(cases[3].associatedValues.count == 3)
        #expect(SBJStructureSampleModel().noCookingInstruction == nil)
    }

    @Test func recipeMetadataSharesTheSameStructuralContract() {
        let properties = SBJStructureSampleModel.sbjProperties
        #expect(properties.contains { $0.sourceName == "name" && $0.kind == .text })
        #expect(properties.contains { $0.sourceName == "ingredients" && $0.kind == .array })
        #expect(properties.contains { $0.sourceName == "cookingStages" && $0.kind == .array })
    }
}
