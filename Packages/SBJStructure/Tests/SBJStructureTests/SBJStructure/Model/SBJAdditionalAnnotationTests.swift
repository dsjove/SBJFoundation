import Foundation
import Testing
@testable import SBJStructure

@SBJStructure
private struct AdditionalRulesFixture {
    @SBJInteger(max: 20) var integer: Int = 20
    @SBJNumber(max: 1.5) var number: Double? = 1.5
    @SBJInteger(max: 255) var bytes: [UInt16] = [255]
    @SBJString(trimming: .whitespace, allowedValues: ["AB12", "CD34"], pattern: "[A-Z]{2}[0-9]{2}")
    var code: String = " AB12 "
    @SBJDictionary(key: [SBJStringRules(allowedValues: ["x"])], value: [SBJNumberRules(max: 2)])
    var settings: [String: Float] = ["x": 2]
    @SBJUnitValue(min: 0) var mass: UnitValue<MassUnit> = .init(2, unit: .gram)
    @SBJInteger(max: 20) var computed: Int { integer }
    var indexed: [Int: String] = [42: "Answer"]
}

@Suite("Additional annotation metadata and invariants")
struct SBJAdditionalAnnotationTests {
    @Test func metadata() throws {
        let type = AdditionalRulesFixture.self
        #expect(type.propertyMetadata(for: \.integer)?.constraints == [.integerRules(.init(max: 20))])
        #expect(type.propertyMetadata(for: \.number)?.constraints == [.numberRules(.init(max: 1.5))])
        #expect(type.propertyMetadata(for: \.computed)?.constraints == [.integerRules(.init(max: 20))])
        #expect(type.propertyMetadata(for: \.code)?.constraints == [.stringRules(.init(trimming: .whitespace, allowedValues: ["AB12", "CD34"], pattern: "[A-Z]{2}[0-9]{2}"))])
        #expect(type.propertyMetadata(for: \.mass)?.constraints.contains(.unitMinimum(0)) == true)
    }

    @Test func validSnapshotAndInvalidFields() {
        let valid = AdditionalRulesFixture()
        #expect(SBJInvariantCheck.validationError(valid, at: .root) == nil)
        #expect(valid.code == " AB12 ")
        var invalid = valid
        invalid.integer = 21
        #expect(SBJInvariantCheck.validationError(invalid, at: .root) != nil)
        invalid = valid; invalid.number = .infinity
        #expect(SBJInvariantCheck.validationError(invalid, at: .root) != nil)
        invalid = valid; invalid.bytes = [256]
        #expect(SBJInvariantCheck.validationError(invalid, at: .root) != nil)
        invalid = valid; invalid.code = "EF56"
        #expect(SBJInvariantCheck.validationError(invalid, at: .root) != nil)
        invalid = valid; invalid.settings = ["x": 3]
        #expect(SBJInvariantCheck.validationError(invalid, at: .root) != nil)
        invalid = valid; invalid.mass = .init(-1, unit: .gram)
        #expect(SBJInvariantCheck.validationError(invalid, at: .root) != nil)
        invalid = valid; invalid.number = nil
        #expect(SBJInvariantCheck.validationError(invalid, at: .root) == nil)
    }

    @Test func typedDictionaryKey() throws {
        let entries = SBJStructuralTraversal.descendants(in: AdditionalRulesFixture())
        let entry = try #require(entries.first { ($0.dictionaryKey as? Int) == 42 })
        #expect(entry.value as? String == "Answer")
        let keyType = try #require(entry.dictionaryKeyType)
        #expect(ObjectIdentifier(keyType) == ObjectIdentifier(Int.self))
    }

    @Test func canonicalNumericBounds() throws {
        let integer = SBJIntegerRules(range: 1...20)
        #expect(integer == SBJIntegerRules(min: 1, max: 20))
        #expect(integer.min == 1)
        #expect(integer.max == 20)
        let number = SBJNumberRules(range: 0.5...2.5)
        #expect(number == SBJNumberRules(min: 0.5, max: 2.5))
        let data = try JSONEncoder().encode(integer)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Int])
        #expect(object == ["min": 1, "max": 20])
        #expect(try JSONDecoder().decode(SBJIntegerRules.self, from: data) == integer)
        try SBJInvariantCheck.requireDictionaryMember(1, rule: integer, at: .root)
        #expect(throws: SBJValidationError.self) { try SBJInvariantCheck.requireDictionaryMember(0, rule: integer, at: .root) }
        #expect(throws: SBJValidationError.self) { try SBJInvariantCheck.requireDictionaryMember(21, rule: integer, at: .root) }
    }

    @Test func numericAndRegexEdges() throws {
        try SBJInvariantCheck.requireMaximum(UInt8.max, 300, at: .root)
        #expect(throws: SBJValidationError.self) { try SBJInvariantCheck.requireMaximum(UInt64.max, Int.max, at: .root) }
        #expect(throws: SBJValidationError.self) { try SBJInvariantCheck.requireMaximum(UInt(0), -1, at: .root) }
        #expect(throws: SBJValidationError.self) { try SBJInvariantCheck.requireMaximum(Double.nan, 1.0, at: .root) }
        try SBJInvariantCheck.requireStringRules("AB", rule: .init(pattern: "A|AB"), at: .root)
        #expect(throws: SBJValidationError.self) { try SBJInvariantCheck.requireStringRules("AB\n", rule: .init(pattern: "AB"), at: .root) }
        #expect(throws: SBJValidationError.self) { try SBJInvariantCheck.requireStringRules("AB", rule: .init(pattern: "["), at: .root) }
        #expect(throws: SBJValidationError.self) { try SBJInvariantCheck.requireStringRules("AB", rule: .init(allowedValues: []), at: .root) }
    }
}
