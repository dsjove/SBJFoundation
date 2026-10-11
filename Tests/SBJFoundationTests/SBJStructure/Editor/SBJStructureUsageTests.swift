import Foundation
import SwiftUI
import Testing
@testable import SBJFoundation

@SBJStructure
private struct TestNestedValue: Codable {
    var note: String = ""
}

@SBJStructure
private struct TestEditableValue: Codable {
    var name: String = ""
    var level: Int = 1
    var nested = TestNestedValue()
    var notes: [String] = []
    var nickname: String?
    @SBJNotEditable var transientState: String = ""
    let immutableIdentifier: Int = 7

    enum CodingKeys: String, CodingKey {
        case name
        case level
        case nested
        case notes
        case nickname
        case transientState
    }
}

struct SBJStructureUsageTests {
    @Test func generatesStructuralMetadataFromCodedStoredProperties() {
        #expect(TestEditableValue.sbjProperties.map(\.sourceName) == [
            "name", "level", "nested", "notes", "nickname", "transientState"
        ])
        #expect(TestEditableValue.sbjProperties.map(\.displayName) == [
            "Name", "Level", "Nested", "Notes", "Nickname", "Transient State"
        ])
    }

    @MainActor
    @Test func generatesFieldsFromCodedMutableProperties() {
        #expect(TestEditableValue.sbjEditorFields.map(\.name) == [
            "Name", "Level", "Nested", "Notes", "Nickname"
        ])
    }
}


private final class TestEditorOnlyReference {}

@SBJStructure
private struct TestEditorOnlyPropertyValue: Codable {
    var stored: String = ""

    @SBJEditorProperty
    var editorReference: TestEditorOnlyReference? {
        get { nil }
        set {}
    }
}

extension SBJStructureUsageTests {
    @MainActor
    @Test func editorPropertyCanExposeNonCodableComputedValueWithoutStructuralMetadata() {
        #expect(TestEditorOnlyPropertyValue.sbjProperties.map(\.sourceName) == ["stored"])
        #expect(TestEditorOnlyPropertyValue.sbjEditorFields.map(\.name) == ["Stored", "Editor Reference"])
    }
}

private struct TestBindingRoot {
    var presentedValue = "original"
    var storedValue = ""
}

extension SBJStructureUsageTests {
    @MainActor
    @Test func registryCanOverrideAPropertyBinding() {
        var root = TestBindingRoot()
        let rootBinding = Binding(
            get: { root },
            set: { root = $0 }
        )
        var registry = SBJEditorRegistry()
        registry.registerBinding(\TestBindingRoot.presentedValue) { root in
            Binding(
                get: { root.wrappedValue.presentedValue },
                set: { root.wrappedValue.storedValue = "staged:\($0)" }
            )
        }

        let binding = registry.customBinding(
            keyPath: \TestBindingRoot.presentedValue,
            root: rootBinding
        )
        binding?.wrappedValue = "replacement"

        #expect(root.presentedValue == "original")
        #expect(root.storedValue == "staged:replacement")
    }
}

@SBJStructure
private enum TestAssociatedEnum: Codable {
    case automatic
    case adjusted(amount: Int, enabled: Bool)
    case fixed(Int)
}

extension SBJStructureUsageTests {
    @Test func generatedEnumSourceCaseNamesPreserveDeclarations() {
        #expect(TestAssociatedEnum.sbjCaseNames == ["automatic", "adjusted", "fixed"])
        #expect(TestAssociatedEnum.automatic.sbjCaseName == "automatic")
        #expect(TestAssociatedEnum.adjusted(amount: 2, enabled: true).sbjCaseName == "adjusted")
        #expect(TestAssociatedEnum.fixed(3).sbjCaseName == "fixed")
    }

    @MainActor
    @Test func generatesAssociatedEnumCasesAndFields() {
        let cases = TestAssociatedEnum.sbjEditorEnumCases
        #expect(cases.map(\.name) == ["Automatic", "Adjusted", "Fixed"])
        #expect(cases[0].associatedValues.isEmpty)
        #expect(cases[1].associatedValues.map(\.name) == ["Amount", "Enabled"])
        #expect(cases[2].associatedValues.map(\.name) == ["Value"])

        let created = TestAssociatedEnum.sbjCreateDefaultValueIfPossible()!
        if case .automatic = created {
            // expected
        } else {
            Issue.record("Expected the first enum case to be the generated default")
        }
    }
}

@SBJStructure
private struct TestContentLeaf: Codable {
    var text: String = ""
}

private enum TestPlainScalarEnum: Codable {
    case first
    case second
}

@SBJStructure
private struct TestGeneratedContent: Codable {
    var scalar: Int = 1
    var text: String = ""
    var optionalText: String?
    var nested = TestContentLeaf()
    var nestedItems: [TestContentLeaf] = []
}

extension SBJStructureUsageTests {
    @Test func generatedHasContentIncludesDirectScalars() {
        #expect(TestGeneratedContent().hasContent)
        #expect(TestGeneratedContent(scalar: 99).hasContent)
        #expect(TestGeneratedContent(text: "x").hasContent)
        #expect(TestGeneratedContent(optionalText: "").hasContent)
        #expect(TestGeneratedContent(optionalText: "x").hasContent)
        #expect(TestGeneratedContent(nested: TestContentLeaf(text: "x")).hasContent)
        #expect(TestGeneratedContent(nestedItems: [TestContentLeaf()]).hasContent)
        #expect(TestGeneratedContent(nestedItems: [TestContentLeaf(text: "x")]).hasContent)
    }

    @Test func contentCheckRecognizesAtomicScalars() {
        #expect(SBJContentCheck.hasContent(0))
        #expect(SBJContentCheck.hasContent(99))
        #expect(SBJContentCheck.hasContent(false))
        #expect(SBJContentCheck.hasContent(TestPlainScalarEnum.first))
        #expect(((0 as Any) as? any HasContentCheckable) == nil)
        #expect(((false as Any) as? any HasContentCheckable) == nil)
        #expect(((TestPlainScalarEnum.first as Any) as? any HasContentCheckable) == nil)
    }

    @Test func presenceBearingContainersStillCountNonCheckableScalars() {
        let noInteger: Int? = nil
        let integer: Int? = 0

        #expect(!SBJContentCheck.hasContent(noInteger))
        #expect(SBJContentCheck.hasContent(integer))
        #expect(!SBJContentCheck.hasContent([Int]()))
        #expect(SBJContentCheck.hasContent([0]))
    }
}

private struct TestPlainAggregate {
    var name: String = ""
    var children: [String] = []
}

private enum TestPayloadEnum {
    case empty
    case text(String)
    case pair(String, Int?)
}

extension SBJStructureUsageTests {
    @Test func structuralContentRulesForPlainValues() {
        #expect(SBJContentCheck.hasContent(0.0))
        #expect(SBJContentCheck.hasContent(false))
        #expect(SBJContentCheck.hasContent(TestPlainScalarEnum.second))
        #expect(!SBJContentCheck.hasContent(TestPlainAggregate()))
        #expect(SBJContentCheck.hasContent(TestPlainAggregate(name: "hello")))
        #expect(!SBJContentCheck.hasContent(TestPayloadEnum.text("")))
        #expect(SBJContentCheck.hasContent(TestPayloadEnum.empty))
        #expect(!SBJContentCheck.hasContent(TestPayloadEnum.pair("", nil)))
        #expect(SBJContentCheck.hasContent(TestPayloadEnum.pair("", 0)))
        #expect(!SBJContentCheck.hasContent(["": ""]))
        #expect(SBJContentCheck.hasContent(["key": "value"]))
        #expect(!SBJContentCheck.hasContent(["": [String]()]))
        #expect(SBJContentCheck.hasContent(["key": [0]]))
    }
}

@SBJStructure
private struct TestValidatedValue: Codable {
    @SBJInteger(range: 1...20)
    var level: Int = 1

    @SBJInteger(min: 0)
    var count: Int = 0

    @SBJString(minLength: 2, maxLength: 5)
    var code: String = "ok"

    @SBJString(minLength: 1, trimming: .whitespaceAndNewlines)
    var trimmedCode: String = "ok"

    @SBJNotEditable
    @SBJString(minLength: 2)
    var hiddenCode: String = "ok"

    @SBJArray(minCount: 1, maxCount: 2)
    var names: [String] = ["one"]

    @SBJOptional(required: true)
    var nickname: String? = "x"

    @SBJNumber(range: 0.0...1.0)
    var boundedNumber: Double = 0.5

    @SBJNumber(min: 0.0)
    var minimumNumber: Double = 1.0

    var ratio: Double = 0.5
}

extension SBJStructureUsageTests {
    @Test func generatedMetadataDescribesDeclaredBusinessRules() {
        let level = TestValidatedValue.propertyMetadata(for: \TestValidatedValue.level)
        #expect(level?.kind == .integer)
        #expect(level?.constraints == [.integerRange(1...20)])

        let code = TestValidatedValue.propertyMetadata(for: \TestValidatedValue.code)
        #expect(code?.kind == .text)
        #expect(code?.constraints == [.textLength(min: 2, max: 5)])

        let nickname = TestValidatedValue.propertyMetadata(for: \TestValidatedValue.nickname)
        #expect(nickname?.kind == .optional)
        #expect(nickname?.constraints == [.required(true)])

        let names = TestValidatedValue.propertyMetadata(for: \TestValidatedValue.names)
        #expect(names?.kind == .array)
        #expect(names?.constraints == [.count(min: 1, max: 2)])

        let minimumNumber = TestValidatedValue.propertyMetadata(for: \TestValidatedValue.minimumNumber)
        #expect(minimumNumber?.kind == .number)
        #expect(minimumNumber?.constraints == [.numberMinimum(0.0)])
    }

    @Test func generatedInvariantUsesDeclaredBusinessRules() throws {
        try TestValidatedValue().invariant(at: \TestValidatedValue.self)

        #expect(throws: SBJValidationError.self) {
            try TestValidatedValue(level: 21).invariant(at: \TestValidatedValue.self)
        }
        #expect(throws: SBJValidationError.self) {
            try TestValidatedValue(count: -1).invariant(at: \TestValidatedValue.self)
        }
        #expect(throws: SBJValidationError.self) {
            try TestValidatedValue(code: "x").invariant(at: \TestValidatedValue.self)
        }
        #expect(throws: SBJValidationError.self) {
            try TestValidatedValue(trimmedCode: "  \n  ").invariant(at: \TestValidatedValue.self)
        }
        #expect(throws: SBJValidationError.self) {
            try TestValidatedValue(hiddenCode: "x").invariant(at: \TestValidatedValue.self)
        }
        #expect(throws: SBJValidationError.self) {
            try TestValidatedValue(names: []).invariant(at: \TestValidatedValue.self)
        }
        #expect(throws: SBJValidationError.self) {
            try TestValidatedValue(nickname: nil).invariant(at: \TestValidatedValue.self)
        }
        #expect(throws: SBJValidationError.self) {
            try TestValidatedValue(minimumNumber: -0.01).invariant(at: \TestValidatedValue.self)
        }
        #expect(throws: SBJValidationError.self) {
            try TestValidatedValue(boundedNumber: 2).invariant(at: \TestValidatedValue.self)
        }

        // Unannotated values have no generated business-rule constraint.
        try TestValidatedValue(ratio: 2).invariant(at: \TestValidatedValue.self)
    }
}

@SBJStructure
private struct TestDocumentedValue: Codable {
    var name: String = ""

    static func propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
        guard (keyPath as AnyKeyPath) == \Self.name else { return nil }
        return SBJPropertyInfo(
            title: "Display Name",
            summary: "A short name.",
            details: "Used to identify the value in user interfaces.",
            accessibilityLabel: "Name field",
            accessibilityHint: "Enter a short name",
            accessibilityValue: "Current name"
        )
    }
}

extension SBJStructureUsageTests {
    @Test func structuralMetadataCarriesReusablePropertyInfo() {
        let property = TestDocumentedValue.propertyMetadata(for: \TestDocumentedValue.name)
        #expect(property?.sourceName == "name")
        #expect(property?.info != nil)
    }

    @Test func annotationsDoNotEnforceOnAssignmentOrAccess() throws {
        var value = TestValidatedValue()
        value.level = 99
        value.code = "x"
        value.names = []
        value.nickname = nil

        #expect(value.level == 99)
        #expect(value.code == "x")
        #expect(value.names.isEmpty)
        #expect(value.nickname == nil)

        #expect(throws: SBJValidationError.self) {
            try value.invariant(at: \TestValidatedValue.self)
        }
    }
}


private struct TestUniqueItem: Codable, Hashable {
    var id: Int
    var name: String
}

@SBJStructure
private struct TestCollectionRules: Codable {
    @SBJArray(unique: true)
    var tags: [String] = []

    @SBJArray(uniqueBy: \TestUniqueItem.id)
    var items: [TestUniqueItem] = []
}

extension SBJStructureUsageTests {
    @Test func arrayUniquenessRulesAreGeneratedAndDescribed() throws {
        let tags = TestCollectionRules.propertyMetadata(for: \TestCollectionRules.tags)
        #expect(tags?.constraints == [.unique])

        let items = TestCollectionRules.propertyMetadata(for: \TestCollectionRules.items)
        #expect(items?.constraints == [.uniqueBy("\\TestUniqueItem.id")])

        try TestCollectionRules(
            tags: ["a", "b"],
            items: [
                TestUniqueItem(id: 1, name: "one"),
                TestUniqueItem(id: 2, name: "two"),
            ]
        ).invariant(at: \TestCollectionRules.self)

        #expect(throws: SBJValidationError.self) {
            try TestCollectionRules(tags: ["a", "a"]).invariant(at: \TestCollectionRules.self)
        }

        #expect(throws: SBJValidationError.self) {
            try TestCollectionRules(items: [
                TestUniqueItem(id: 1, name: "one"),
                TestUniqueItem(id: 1, name: "another"),
            ]).invariant(at: \TestCollectionRules.self)
        }
    }

    @Test func validationErrorSnapshotsTheFailingValue() {
        let path = SBJValidationKeyPath(\TestEditableValue.level)

        do {
            try SBJInvariantCheck.requireRange(37, 1...30, at: path)
            Issue.record("Expected range validation to fail")
        } catch let error as SBJValidationError {
            #expect(error.valueDescription == "37")
            #expect(error.message == "must be in 1...30")
        } catch {
            Issue.record("Expected SBJValidationError")
        }
    }

    @Test func structureDiagnosticsKeepValueSeparateFromValidationMessage() {
        let error = SBJValidationError(37, at: SBJValidationKeyPath(\TestEditableValue.level), "must be in 1...30")
        let issue = SBJEditorIssue.validation(
            path: error.keyPath.description,
            valueDescription: error.valueDescription,
            message: error.message
        )

        #expect(issue.valueDescription == "37")
        #expect(issue.message == "must be in 1...30")
    }

    @Test func uniqueByReportsTheDuplicateArrayPosition() {
        let values = [
            TestUniqueItem(id: 1, name: "one"),
            TestUniqueItem(id: 1, name: "two"),
        ]
        let path = SBJValidationKeyPath(\TestCollectionRules.items)

        do {
            try SBJInvariantCheck.requireUnique(values, by: \TestUniqueItem.id, at: path)
            Issue.record("Expected duplicate key validation to fail")
        } catch let error as SBJValidationError {
            #expect(error.keyPath.description.hasSuffix("[1]"))
        } catch {
            Issue.record("Expected SBJValidationError")
        }
    }
}

@SBJStructure
private struct TestInvalidNestedValue: Codable, Hashable {
    @SBJString(minLength: 2)
    var code: String = "ok"
}

@SBJStructure
private struct TestValidationContainers: Codable {
    var keyed: [String: TestInvalidNestedValue] = [:]
    var members: Set<TestInvalidNestedValue> = []
}

extension SBJStructureUsageTests {
    @Test func nestedDictionaryValidationRetainsTheDictionaryKey() {
        let value = TestValidationContainers(
            keyed: ["bad": TestInvalidNestedValue(code: "x")]
        )

        do {
            try value.invariant(at: \TestValidationContainers.self)
            Issue.record("Expected nested dictionary validation to fail")
        } catch let error as SBJValidationError {
            #expect(error.keyPath.description.contains("bad"))
            #expect(error.keyPath.contains(property: \TestValidationContainers.keyed))
        } catch {
            Issue.record("Expected SBJValidationError")
        }
    }

    @Test func nestedSetValidationIdentifiesTheMember() {
        let invalid = TestInvalidNestedValue(code: "x")
        let value = TestValidationContainers(members: [invalid])

        do {
            try value.invariant(at: \TestValidationContainers.self)
            Issue.record("Expected nested set validation to fail")
        } catch let error as SBJValidationError {
            #expect(error.keyPath.description.contains("TestInvalidNestedValue"))
            #expect(error.keyPath.contains(property: \TestValidationContainers.members))
        } catch {
            Issue.record("Expected SBJValidationError")
        }
    }

    @Test func countValidationWorksAcrossCollectionTypes() throws {
        let setPath = SBJValidationKeyPath(\TestValidationContainers.members)
        try SBJInvariantCheck.requireCount(Set([1, 2]), minCount: 1, maxCount: 2, at: setPath)
        #expect(throws: SBJValidationError.self) {
            try SBJInvariantCheck.requireCount(Set<Int>(), minCount: 1, maxCount: nil, at: setPath)
        }

        let dictionaryPath = SBJValidationKeyPath(\TestValidationContainers.keyed)
        try SBJInvariantCheck.requireCount(["one": 1], minCount: nil, maxCount: 1, at: dictionaryPath)
        #expect(throws: SBJValidationError.self) {
            try SBJInvariantCheck.requireCount(["one": 1, "two": 2], minCount: nil, maxCount: 1, at: dictionaryPath)
        }
    }
}

extension SBJStructureUsageTests {
    @Test func dataByteConstraintsAreCentralized() throws {
        let path = SBJValidationKeyPath(\TestDataConstraintHolder.payload)

        try SBJInvariantCheck.requireData(Data(repeating: 0, count: 8), min: 4, max: 12, modulo: 4, at: path)

        #expect(throws: SBJValidationError.self) {
            try SBJInvariantCheck.requireData(Data(repeating: 0, count: 2), min: 4, at: path)
        }
        #expect(throws: SBJValidationError.self) {
            try SBJInvariantCheck.requireData(Data(repeating: 0, count: 16), max: 12, at: path)
        }
        #expect(throws: SBJValidationError.self) {
            try SBJInvariantCheck.requireData(Data(repeating: 0, count: 6), modulo: 4, at: path)
        }
    }
}

private struct TestDataConstraintHolder {
    var payload = Data()
}

@SBJStructure
private struct TestPhase4Collections: Codable {
    @SBJArray(reorderable: false, title: \TestUniqueItem.name, minCount: 1, maxCount: 3, uniqueBy: \TestUniqueItem.id)
    var items: [TestUniqueItem] = [TestUniqueItem(id: 1, name: "one")]

    @SBJSet(title: \TestUniqueItem.name, minCount: 1, maxCount: 2)
    var members: Set<TestUniqueItem> = [TestUniqueItem(id: 1, name: "one")]

    @SBJDictionary(minCount: 1, maxCount: 2)
    var labels: [String: Int] = ["one": 1]
}

extension SBJStructureUsageTests {
    @Test func phase4CollectionAnnotationsGenerateKindsRulesAndHints() {
        let items = TestPhase4Collections.propertyMetadata(for: \TestPhase4Collections.items)
        #expect(items?.kind == .array)
        #expect(items?.constraints == [
            .count(min: 1, max: 3),
            .uniqueBy("\\TestUniqueItem.id"),
        ])
        #expect(items?.hints == [
            .reorderable(false),
            .itemTitle("name"),
        ])

        let members = TestPhase4Collections.propertyMetadata(for: \TestPhase4Collections.members)
        #expect(members?.kind == .set)
        #expect(members?.constraints == [.count(min: 1, max: 2)])
        #expect(members?.hints == [.itemTitle("name")])

        let labels = TestPhase4Collections.propertyMetadata(for: \TestPhase4Collections.labels)
        #expect(labels?.kind == .dictionary)
        #expect(labels?.constraints == [.count(min: 1, max: 2)])
        #expect(labels?.hints.isEmpty == true)
    }

    @Test func phase4SetAndDictionaryCountsParticipateInExplicitInvariant() throws {
        try TestPhase4Collections().invariant(at: \TestPhase4Collections.self)

        #expect(throws: SBJValidationError.self) {
            try TestPhase4Collections(members: []).invariant(at: \TestPhase4Collections.self)
        }
        #expect(throws: SBJValidationError.self) {
            try TestPhase4Collections(labels: [:]).invariant(at: \TestPhase4Collections.self)
        }
        #expect(throws: SBJValidationError.self) {
            try TestPhase4Collections(
                labels: ["one": 1, "two": 2, "three": 3]
            ).invariant(at: \TestPhase4Collections.self)
        }
    }

    @Test func setReplacementRejectsCollisionsWithoutChangingCollection() {
        var values: Set<String> = ["one", "two"]
        let collisionRejected = !values.sbjReplace("one", with: "two")
        #expect(collisionRejected)
        #expect(values == ["one", "two"])

        let replacementSucceeded = values.sbjReplace("one", with: "three")
        #expect(replacementSucceeded)
        #expect(values == ["two", "three"])
    }

    @Test func dictionaryRenameRejectsCollisionsAndPreservesValues() {
        var values = ["one": 1, "two": 2]
        let collisionRejected = !values.sbjRenameKey("one", to: "two")
        #expect(collisionRejected)
        #expect(values == ["one": 1, "two": 2])

        let renameSucceeded = values.sbjRenameKey("one", to: "three")
        #expect(renameSucceeded)
        #expect(values == ["three": 1, "two": 2])
    }

}

@SBJStructure
private struct TestScalarAnnotations: Codable {
    var url = URL(string: "https://example.com")!
    @SBJUUID(nonzero: true) var uuid = UUID()
    @SBJDate(range: Date(timeIntervalSince1970: 0)...Date(timeIntervalSince1970: 100)) var date = Date(timeIntervalSince1970: 0)
    @SBJData(min: 4, max: 8, modulo: 4) var data = Data([0, 1, 2, 3])
    @SBJColor(alpha: false) var color = CodableColor(1, 0, 0)
}

extension SBJStructureUsageTests {
    @Test func scalarAnnotationsProduceStructuralKindsAndDataRules() throws {
        #expect(TestScalarAnnotations.propertyMetadata(for: \TestScalarAnnotations.url)?.kind == .url)
        #expect(TestScalarAnnotations.propertyMetadata(for: \TestScalarAnnotations.uuid)?.kind == .uuid)
        #expect(TestScalarAnnotations.propertyMetadata(for: \TestScalarAnnotations.date)?.kind == .date)
        #expect(TestScalarAnnotations.propertyMetadata(for: \TestScalarAnnotations.color)?.kind == .color)
        #expect(TestScalarAnnotations.propertyMetadata(for: \TestScalarAnnotations.data)?.constraints == [
            .dataSize(min: 4, max: 8, modulo: 4)
        ])
        #expect(TestScalarAnnotations.propertyMetadata(for: \TestScalarAnnotations.uuid)?.constraints == [.uuidNonzero])
        #expect(TestScalarAnnotations.propertyMetadata(for: \TestScalarAnnotations.date)?.constraints == [
            .dateRange(Date(timeIntervalSince1970: 0)...Date(timeIntervalSince1970: 100))
        ])
        #expect(TestScalarAnnotations.propertyMetadata(for: \TestScalarAnnotations.color)?.hints == [.colorSupportsAlpha(false)])

        try TestScalarAnnotations().invariant(at: \TestScalarAnnotations.self)
        #expect(throws: SBJValidationError.self) {
            try TestScalarAnnotations(data: Data([0, 1, 2])).invariant(at: \TestScalarAnnotations.self)
        }
        #expect(throws: SBJValidationError.self) {
            try TestScalarAnnotations(data: Data(repeating: 0, count: 12)).invariant(at: \TestScalarAnnotations.self)
        }
        #expect(throws: SBJValidationError.self) {
            try TestScalarAnnotations(uuid: .sbjZero).invariant(at: \TestScalarAnnotations.self)
        }
        #expect(throws: SBJValidationError.self) {
            try TestScalarAnnotations(date: Date(timeIntervalSince1970: 101)).invariant(at: \TestScalarAnnotations.self)
        }
    }

    @Test func hexEditingFormatRoundTripsAndRejectsIncompleteBytes() throws {
        let data = Data([0x01, 0x23, 0xAB, 0xCD])
        let text = data.sbjHexFormat(bytesPerRow: 2)
        #expect(text == "01 23\nAB CD")
        #expect(try text.sbjHexData() == data)
        #expect(try "01.23 AB-CD".sbjHexData() == data)
        #expect(throws: SBJHexError.incompleteByte) {
            try "ABC".sbjHexData()
        }
    }
}

@SBJStructure
private struct TestPhase6MetadataDrivenEditor: Codable {
    @SBJString(.multiline, minLength: 2, maxLength: 20, autocorrect: .disabled, capitalization: .sentences)
    var notes: String = "ok"

    @SBJString(.sheetEdit)
    var longNotes: String = "longer text"

    @SBJInteger(range: 1...9)
    var count: Int = 1
}

extension SBJStructureUsageTests {
    @Test func phase6PresentationAndConstraintsAreAvailableThroughStructuralMetadata() {
        let notes = TestPhase6MetadataDrivenEditor.propertyMetadata(for: \TestPhase6MetadataDrivenEditor.notes)
        #expect(notes?.hints == [
            .textStyle(.multiline),
            .textAutocorrection(.disabled),
            .textCapitalization(.sentences),
        ])
        #expect(notes?.constraints == [.textLength(min: 2, max: 20)])

        let longNotes = TestPhase6MetadataDrivenEditor.propertyMetadata(for: \TestPhase6MetadataDrivenEditor.longNotes)
        #expect(longNotes?.hints == [.textStyle(.sheetEdit)])

        let count = TestPhase6MetadataDrivenEditor.propertyMetadata(for: \TestPhase6MetadataDrivenEditor.count)
        #expect(count?.constraints == [.integerRange(1...9)])
    }
}

private enum TestCaseIterableChoice: String, Codable, CaseIterable, Hashable {
    case firstChoice
    case secondChoice
}

@SBJStructure
private struct TestDefaultedInitializer: Codable {
    var name: String

    init(name: String = "default") {
        self.name = name
    }
}

@SBJStructure
private struct TestRequiresCreationContext: Codable {
    var name: String

    init(name: String) {
        self.name = name
    }
}

private struct TestContextualCollectionValue: Equatable, SBJCollectionElementCreatable {
    var index: Int

    static func sbjCreateValue(existing: [Self]) -> Self? {
        let used = Set(existing.map(\.index))
        guard let index = (0...2).first(where: { !used.contains($0) }) else { return nil }
        return .init(index: index)
    }
}

extension SBJStructureUsageTests {
    @Test func structuredDefaultCreationIsGeneratedWhenInitNeedsNoArguments() {
        let direct = TestEditableValue.sbjDefaultValue()
        #expect(direct != nil)
        #expect(direct?.name == "")
        #expect(direct?.level == 1)

        let throughFactory = SBJDefaultValue.value(for: TestEditableValue.self)
        #expect(throughFactory != nil)
        #expect(throughFactory?.nested.note == "")

        #expect(TestDefaultedInitializer.sbjDefaultValue()?.name == "default")
    }

    @Test func structuredDefaultCreationRemainsNilWhenContextIsRequired() {
        #expect(TestRequiresCreationContext.sbjDefaultValue() == nil)
        #expect(SBJDefaultValue.value(for: TestRequiresCreationContext.self) == nil)
    }

    @Test func plainCaseIterableEnumsUseFirstCaseWithoutEditorProtocol() {
        let created = SBJDefaultValue.value(for: TestCaseIterableChoice.self)
        #expect(created == .firstChoice)
    }

    @Test func contextualCollectionCreationUsesModelLevelFactory() {
        let registry = SBJEditorRegistry()
        let created = registry.createArrayElement(
            TestContextualCollectionValue.self,
            existing: [.init(index: 0), .init(index: 2)]
        )
        #expect(created == .init(index: 1))

        let unavailable = registry.createArrayElement(
            TestContextualCollectionValue.self,
            existing: [.init(index: 0), .init(index: 1), .init(index: 2)]
        )
        #expect(unavailable == nil)
    }
}


private struct TestNonHashableCaseIterable: Codable, CaseIterable {
    let rawValue: String

    static let first = Self(rawValue: "first")
    static let second = Self(rawValue: "second")
    static let allCases = [first, second]
}

@SBJStructure
private struct TestEditorDiagnosticsOwnerConstraint: Codable {
    @SBJInteger(range: 1...3)
    var value: Int = 5
}

@SBJStructure
private struct TestUnsupportedCaseIterableContainer: Codable {
    var choice: TestNonHashableCaseIterable = .first
}

extension SBJStructureUsageTests {
    @MainActor
    @Test func editorDiagnosticsPreserveTheSourcePassAndLocation() {
        let validationIssues = SBJEditorDiagnostics.issues(for: TestEditorDiagnosticsOwnerConstraint())
        #expect(validationIssues.count == 1)
        #expect(validationIssues[0].kind == .validation)
        #expect(validationIssues[0].path == "Value")
        #expect(validationIssues[0].typeName == "Validation")

        let capabilityIssues = SBJEditorDiagnostics.issues(for: TestUnsupportedCaseIterableContainer())
        #expect(capabilityIssues.count == 1)
        #expect(capabilityIssues[0].kind == .unsupported)
        #expect(capabilityIssues[0].path == "Choice")
    }
}

@SBJStructure
private struct TestExpandedScalarValidation: Codable {
    @SBJInteger(range: 1...9)
    var signedSmall: Int8 = 2

    @SBJInteger(min: 1)
    var unsigned: UInt16 = 2

    @SBJNumber(range: 0.0...10.0)
    var float: Float = 2

    @SBJNumber(range: 0.0...10.0)
    var decimal: Decimal = 2

    @SBJUUID(nonzero: true)
    var optionalID: UUID? = UUID()

    @SBJDate(range: Date(timeIntervalSince1970: 0)...Date(timeIntervalSince1970: 100))
    var optionalDate: Date? = Date(timeIntervalSince1970: 50)

    @SBJData(min: 2, max: 4, modulo: 2)
    var optionalData: Data? = Data([1, 2])
}

extension SBJStructureUsageTests {
    @Test func expandedScalarFamiliesUseGeneratedValidation() throws {
        try TestExpandedScalarValidation().invariant(at: \TestExpandedScalarValidation.self)

        var badInteger = TestExpandedScalarValidation()
        badInteger.signedSmall = 10
        #expect(throws: SBJValidationError.self) {
            try badInteger.invariant(at: \TestExpandedScalarValidation.self)
        }

        var badUnsigned = TestExpandedScalarValidation()
        badUnsigned.unsigned = 0
        #expect(throws: SBJValidationError.self) {
            try badUnsigned.invariant(at: \TestExpandedScalarValidation.self)
        }

        var badFloat = TestExpandedScalarValidation()
        badFloat.float = 11
        #expect(throws: SBJValidationError.self) {
            try badFloat.invariant(at: \TestExpandedScalarValidation.self)
        }

        var badDecimal = TestExpandedScalarValidation()
        badDecimal.decimal = 11
        #expect(throws: SBJValidationError.self) {
            try badDecimal.invariant(at: \TestExpandedScalarValidation.self)
        }

        var badID = TestExpandedScalarValidation()
        badID.optionalID = .sbjZero
        #expect(throws: SBJValidationError.self) {
            try badID.invariant(at: \TestExpandedScalarValidation.self)
        }

        var badDate = TestExpandedScalarValidation()
        badDate.optionalDate = Date(timeIntervalSince1970: 101)
        #expect(throws: SBJValidationError.self) {
            try badDate.invariant(at: \TestExpandedScalarValidation.self)
        }

        var badData = TestExpandedScalarValidation()
        badData.optionalData = Data([1, 2, 3])
        #expect(throws: SBJValidationError.self) {
            try badData.invariant(at: \TestExpandedScalarValidation.self)
        }
    }
}

@SBJStructure
private struct TestNestedValidationLeaf: Codable {
    @SBJInteger(range: 1...3)
    var value: Int = 5
}

@SBJStructure
private struct TestNestedValidationParent: Codable {
    var child: TestNestedValidationLeaf = .init()
}

extension SBJStructureUsageTests {
    @MainActor
    @Test func editorDiagnosticsSuppressPropagatedParentValidationCopies() {
        let issues = SBJEditorDiagnostics.issues(for: TestNestedValidationParent())
        let validationIssues = issues.filter { $0.kind == .validation }
        #expect(validationIssues.count == 1)
        #expect(validationIssues[0].path == "Child › Value")
    }
}

extension SBJStructureUsageTests {
    @Test func structureDiagnosticsReportOwnerDeclaredConstraintAtProperty() {
        let issues = SBJStructureDiagnostics.issues(for: TestEditorDiagnosticsOwnerConstraint())
        #expect(issues.count == 1)
        #expect(issues[0].kind == .validation)
        #expect(issues[0].path == "Value")
        #expect(issues[0].typeName == "Validation")
    }

    @MainActor
    @Test func capabilityDiagnosticsDoNotContainStructuralValidation() {
        #expect(SBJEditorCapabilityDiagnostics.issues(for: TestEditorDiagnosticsOwnerConstraint()).isEmpty)
        #expect(SBJStructureDiagnostics.issues(for: TestEditorDiagnosticsOwnerConstraint()).count == 1)
    }

    @MainActor
    @Test func customEditorRemovesOnlyTheMatchingCapabilityIssue() {
        let value = TestUnsupportedCaseIterableContainer()
        let baseline = SBJEditorCapabilityDiagnostics.issues(for: value)
        #expect(baseline.count == 1)
        #expect(baseline[0].path == "Choice")

        var registry = SBJEditorRegistry()
        registry.register(TestNonHashableCaseIterable.self) { _, _, _ in
            EmptyView()
        }

        #expect(SBJEditorCapabilityDiagnostics.issues(for: value, registry: registry).isEmpty)
    }

    @MainActor
    @Test func customEditorDoesNotChangeStructuralValidation() {
        let value = TestEditorDiagnosticsOwnerConstraint()
        let baseline = SBJEditorDiagnostics.issues(for: value).filter { $0.kind == .validation }

        var registry = SBJEditorRegistry()
        registry.register(Int.self) { _, _, _ in EmptyView() }

        let withCustomEditor = SBJEditorDiagnostics.issues(for: value, registry: registry)
            .filter { $0.kind == .validation }

        #expect(baseline.count == 1)
        #expect(baseline[0].path == "Value")
        #expect(withCustomEditor == baseline)
    }
}

@SBJStructure
private struct TestTitledValidationItem: Codable, Hashable {
    var name: String = ""

    @SBJString(minLength: 2)
    var code: String = "ok"
}

@SBJStructure
private struct TestTitledValidationContainer: Codable {
    @SBJArray(title: \TestTitledValidationItem.name)
    var abilities: [TestTitledValidationItem] = []
}

extension SBJStructureUsageTests {
    @Test func validationPathUsesAnnotatedCollectionTitleForPresentation() {
        let value = TestTitledValidationContainer(
            abilities: [TestTitledValidationItem(name: "Strength", code: "x")]
        )

        do {
            try value.invariant(at: \TestTitledValidationContainer.self)
            Issue.record("Expected nested array validation to fail")
        } catch let error as SBJValidationError {
            #expect(error.keyPath.description == "Abilities › Strength › Code")
            #expect(error.keyPath.debugDescription.contains("[0]"))
            #expect(error.keyPath.debugDescription.contains("TestTitledValidationContainer.abilities"))
            #expect(error.keyPath.debugDescription.contains("TestTitledValidationItem.code"))
            #expect(!error.keyPath.description.contains("TestTitledValidationItem"))
            #expect(!error.keyPath.description.contains("[0]"))
        } catch {
            Issue.record("Expected SBJValidationError")
        }
    }
}
