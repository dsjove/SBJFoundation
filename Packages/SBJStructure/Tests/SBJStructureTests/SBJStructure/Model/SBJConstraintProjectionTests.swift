import Foundation
import Testing
@testable import SBJStructure

@SBJStructure
private struct BoundProjectionFixture {
    @SBJInteger(min: 1, max: 20) var integer: Int = 10
    @SBJInteger(range: 1...20) var rangeInteger: Int = 10
    @SBJNumber(min: 0.5, max: 2.5) var number: Double = 1
    @SBJNumber(range: 0.5...2.5) var rangeNumber: Double = 1
}

@Test func combinedBoundsGenerateOneRule() {
    let type = BoundProjectionFixture.self
    #expect(type.propertyMetadata(for: \.integer)?.constraints == [.integerRules(.init(min: 1, max: 20))])
    #expect(type.propertyMetadata(for: \.integer)?.constraints == type.propertyMetadata(for: \.rangeInteger)?.constraints)
    #expect(type.propertyMetadata(for: \.number)?.constraints == [.numberRules(.init(min: 0.5, max: 2.5))])
    #expect(type.propertyMetadata(for: \.number)?.constraints == type.propertyMetadata(for: \.rangeNumber)?.constraints)
    var fixture = BoundProjectionFixture()
    #expect(SBJInvariantCheck.validationError(fixture, at: .root) == nil)
    fixture.integer = 0
    #expect(SBJInvariantCheck.validationError(fixture, at: .root) != nil)
    fixture.integer = 21
    #expect(SBJInvariantCheck.validationError(fixture, at: .root) != nil)
    fixture.integer = 10; fixture.number = 0.4
    #expect(SBJInvariantCheck.validationError(fixture, at: .root) != nil)
    fixture.number = 2.6
    #expect(SBJInvariantCheck.validationError(fixture, at: .root) != nil)
}

@Test func sharedBoundsIntersectWithoutTrapping() {
    #expect(SBJConstraintProjection([.integerRules(.init(max: 10)), .integerRules(.init(min: 2)), .integerRules(.init(max: 8))]).integerRange == 2...8)
    #expect(SBJConstraintProjection([.integerRules(.init(max: 8))]).integerRange == Int.min...8)
    #expect(SBJConstraintProjection([.integerRules(.init(min: 9, max: 8))]).integerRange == nil)
    #expect(SBJConstraintProjection([.numberRules(.init(min: -1, max: 1))]).numberRange == -1.0...1.0)
    #expect(SBJConstraintProjection().integerRange == nil)
}

@Test func choicesUseSharedValidationAndKeepOrder() {
    let projection = SBJConstraintProjection([
        .stringRules(.init(trimming: .whitespace, allowedValues: ["BA", "AB", "12", "BA"])),
        .stringRules(.init(trimming: .whitespace, pattern: "[A-Z]{2}"))
    ])
    #expect(projection.allowedStrings == ["BA", "AB"])
    #expect(projection.acceptsString(" AB "))
    #expect(projection.matchesStringChoice("AB", current: " AB "))
    #expect(!projection.acceptsString("12"))
    #expect(projection.scalarValidationError(for: "12") != nil)
    #expect(SBJConstraintProjection().allowedStrings == nil)
    #expect(SBJConstraintProjection([.stringRules(.init(allowedValues: []))]).allowedStrings == [])
}

@Test func dictionaryRulesProjectToCorrectMember() {
    let projection = SBJConstraintProjection([
        .dictionaryRules(.init(minCount: 1)),
        .dictionaryKeyRule(.string(.init(allowedValues: ["one", "two"]))),
        .dictionaryValueRule(.integer(.init(min: 1, max: 10)))
    ])
    #expect(projection.dictionaryKey.allowedStrings == ["one", "two"])
    #expect(projection.dictionaryKey.integerRange == nil)
    #expect(projection.dictionaryValue.integerRange == 1...10)
    #expect(projection.dictionaryValue.allowedStrings == nil)
    #expect(projection.dictionaryValue.scalarValidationError(for: UInt8(11)) != nil)
    #expect(projection.dictionaryValue.scalarValidationError(for: UInt8(10)) == nil)
    let array = SBJConstraintProjection([.arrayRules(.init(minCount: 2)), .integerRules(.init(min: 3, max: 18))])
    #expect(array.collectionElement.constraints == [.integerRules(.init(min: 3, max: 18))])
    #expect(SBJConstraintProjection([.unitMinimum(2), .unitMinimum(3)]).unitMinimum == 3)
}

@Test func dictionaryKeyReplacementPreservesOptionalValueAndRejectsCollision() {
    var entries: [String: Int?] = ["old": nil, "occupied": 42]
    let collision = entries.sbjReplaceKey("old", with: "occupied")
    #expect(!collision)
    #expect(entries.keys.contains("old"))
    let renamed = entries.sbjReplaceKey("old", with: "new")
    #expect(renamed)
    #expect(!entries.keys.contains("old"))
    #expect(entries.keys.contains("new"))
    #expect(entries["new"]! == nil)
    #expect(entries["occupied"]! == 42)
    let missing = entries.sbjReplaceKey("missing", with: "new")
    #expect(!missing)
}

@Test func unitMinimumUsesStoredMagnitudeAfterConversion() throws {
    let mass = UnitValue<MassUnit>(100, unit: .gram)
    try SBJInvariantCheck.requireMinimum(mass, 1, at: .root)
    let converted = mass.converted(to: .kilogram)
    #expect(throws: SBJValidationError.self) { try SBJInvariantCheck.requireMinimum(converted, 1, at: .root) }
}
