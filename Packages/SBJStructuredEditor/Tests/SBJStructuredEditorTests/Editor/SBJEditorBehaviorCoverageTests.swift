import Foundation
import Testing
@testable import SBJStructuredEditor
import SBJUIVocabulary
import SBJUnits

private struct Phase7Item: Codable, Hashable {
    var id: Int
    var name: String
}

@SBJEditable
private struct Phase7RuleModel: Codable {
    @SBJString(minLength: 1, maxLength: 8)
    @SBJEditorString(.multiline)
    var text: String = "a"

    @SBJInteger(range: 1...3)
    var integer: Int = 1

    @SBJNumber(range: 0...1)
    var number: Double = 0.5

    @SBJOptional(required: false)
    var optional: String?

    @SBJArray(reorderable: true, minCount: 1, maxCount: 2, uniqueBy: \Phase7Item.id)
    @SBJEditorArray(title: \Phase7Item.name)
    var array: [Phase7Item] = [.init(id: 1, name: "one")]

    @SBJSet(minCount: 1, maxCount: 2)
    @SBJEditorSet(title: \Phase7Item.name)
    var set: Set<Phase7Item> = [.init(id: 1, name: "one")]

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

    @SBJColor(alpha: false)
    var color = CodableColor(1, 0, 0)
}

struct SBJPhase7CoverageTests {
    @Test func structuralMetadataCoversEveryCurrentAnnotationFamily() {
        let kinds = Dictionary(uniqueKeysWithValues: Phase7RuleModel.sbjProperties.map { ($0.sourceName, $0.kind) })

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
        let text = Phase7RuleModel.propertyMetadata(for: \Phase7RuleModel.text)
        #expect(text?.constraints == [.textLength(min: 1, max: 8)])
        #expect(text?.hints == [.textStyle(.multiline)])

        let optional = Phase7RuleModel.propertyMetadata(for: \Phase7RuleModel.optional)
        #expect(optional?.constraints == [.required(false)])

        let array = Phase7RuleModel.propertyMetadata(for: \Phase7RuleModel.array)
        #expect(array?.constraints == [.count(min: 1, max: 2), .uniqueBy("\\Phase7Item.id"), .reorderable(true)])
        #expect(array?.constraints.contains(.reorderable(true)) == true && array?.hints == [.itemTitle("name")])

        let set = Phase7RuleModel.propertyMetadata(for: \Phase7RuleModel.set)
        #expect(set?.constraints == [.count(min: 1, max: 2)])
        #expect(set?.hints == [.itemTitle("name")])

        let data = Phase7RuleModel.propertyMetadata(for: \Phase7RuleModel.data)
        #expect(data?.constraints == [.dataSize(min: 2, max: 4, modulo: 2)])

        let url = Phase7RuleModel.propertyMetadata(for: \Phase7RuleModel.url)
        #expect(url?.constraints == [.urlKinds([.network])])

        let uuid = Phase7RuleModel.propertyMetadata(for: \Phase7RuleModel.uuid)
        #expect(uuid?.constraints == [.uuidNonzero])

        let date = Phase7RuleModel.propertyMetadata(for: \Phase7RuleModel.date)
        #expect(date?.constraints == [.dateRange(Date(timeIntervalSince1970: 0)...Date(timeIntervalSince1970: 100))])

        let color = Phase7RuleModel.propertyMetadata(for: \Phase7RuleModel.color)
        #expect(color?.hints == [.colorSupportsAlpha(false)])

        var value = Phase7RuleModel()
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
            try value.invariant(at: \Phase7RuleModel.self)
        }
    }

    @MainActor
    @Test func generatedEditorFieldsRemainMainActorIsolatedAndExcludeNoEditorPropertiesOnly() {
        #expect(Phase7RuleModel.sbjEditorFields.map(\.name) == [
            "Text", "Integer", "Number", "Optional", "Array", "Set", "Dictionary",
            "Url", "Uuid", "Date", "Data", "Color",
        ])
    }

    @Test func floatingPointValidationRejectsNonFiniteValues() {
        let path = SBJValidationKeyPath(\Phase7RuleModel.number)
        #expect(throws: SBJValidationError.self) {
            try SBJInvariantCheck.requireRange(Double.nan, 0...1, at: path)
        }
        #expect(throws: SBJValidationError.self) {
            try SBJInvariantCheck.requireRange(Double.infinity, 0...1, at: path)
        }
    }

    @Test func hexParserCoversFormattingEmptyInputAndFailures() throws {
        #expect(try "".sbjHexData() == Data())
        #expect(try "01:23_45-67.89 AB\nCD".sbjHexData() == Data([0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD]))
        #expect(try "aa bb cc".sbjHexData() == Data([0xAA, 0xBB, 0xCC]))
        #expect(throws: SBJHexError.incompleteByte) {
            try "0".sbjHexData()
        }
        #expect(throws: SBJHexError.invalidCharacter("G")) {
            try "0G".sbjHexData()
        }
        #expect("0G".sbjHexToData() == nil)
    }

    @Test func hexFormatterHasStableEditorFriendlyOutput() {
        let value = Data([0x00, 0x01, 0xAB, 0xFF])
        #expect(value.sbjHexFormat(bytesPerRow: 2) == "00 01\nAB FF")
        #expect(value.sbjHexFormat(bytesPerRow: 0) == "00\n01\nAB\nFF")
        #expect(value.sbjHexFormat(bytesPerRow: 2, indent: "  ") == "  00 01\n  AB FF")
        #expect(Data().sbjHexFormat().isEmpty)
    }

    @Test func dataConstraintBoundariesAreInclusiveAndModuloIsExplicit() throws {
        let path = SBJValidationKeyPath(\Phase7RuleModel.data)
        try SBJInvariantCheck.requireData(Data(repeating: 0, count: 2), min: 2, max: 4, modulo: 2, at: path)
        try SBJInvariantCheck.requireData(Data(repeating: 0, count: 4), min: 2, max: 4, modulo: 2, at: path)

        #expect(throws: SBJValidationError.self) {
            try SBJInvariantCheck.requireData(Data(repeating: 0, count: 3), min: 2, max: 4, modulo: 2, at: path)
        }
        #expect(throws: SBJValidationError.self) {
            try SBJInvariantCheck.requireData(Data(), modulo: 0, at: path)
        }
    }
}

extension SBJPhase7CoverageTests {
    @Test func smartURLParsingIsPermissiveAndTrimsWhitespace() {
        #expect(" https://example.com/path ".sbjURL?.absoluteString == "https://example.com/path")
        #expect("mailto:test@example.com".sbjURL?.scheme == "mailto")
        #expect("relative/path".sbjURL?.relativeString == "relative/path")
        #expect("example.com".sbjURL?.relativeString == "example.com")
    }

    @Test func urlKindsAreExplicitInvariantConstraints() throws {
        let path = SBJValidationKeyPath(\Phase7RuleModel.url)
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
        var value = Phase7RuleModel()
        value.url = URL(fileURLWithPath: "/tmp/local")
        #expect(value.url.isFileURL)
        #expect(throws: SBJValidationError.self) {
            try value.invariant(at: \Phase7RuleModel.self)
        }
    }

    @Test func smartUUIDParsingAcceptsCanonicalCompactAndBracedForms() {
        let expected = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!
        #expect("550E8400-E29B-41D4-A716-446655440000".sbjUUID == expected)
        #expect("550E8400E29B41D4A716446655440000".sbjUUID == expected)
        #expect("{550e8400-e29b-41d4-a716-446655440000}".sbjUUID == expected)
        #expect("not-a-uuid".sbjUUID == nil)
    }
}

private struct SBJUtilityCopyValue: Codable, Equatable {
    var name: String
    var count: Int
}

extension SBJPhase7CoverageTests {
    @Test func publicCodableUtilitiesSupportSnapshotsAndChangeComparison() {
        let original = SBJUtilityCopyValue(name: "one", count: 1)
        let copy = original.sbjCodableCopy()
        #expect(copy == original)
        #expect(!copy.sbjEncodedIsDifferent(from: original))

        let changed = SBJUtilityCopyValue(name: "one", count: 2)
        #expect(changed.sbjEncodedIsDifferent(from: original))
    }
}

@SBJEditable
private struct Phase9CodingShapeModel: Codable {
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

extension SBJPhase7CoverageTests {
    @Test func codingKeysDefineStructureAndAnnotationsAreNotRequiredForKinds() {
        let metadata = Dictionary(uniqueKeysWithValues: Phase9CodingShapeModel.sbjProperties.map { ($0.sourceName, $0.kind) })
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

        let path = SBJValidationKeyPath(\Phase7RuleModel.uuid)
        #expect(throws: SBJValidationError.self) {
            try SBJInvariantCheck.requireNonzero(.sbjZero, at: path)
        }
        try SBJInvariantCheck.requireNonzero(UUID(), at: path)
    }
}
