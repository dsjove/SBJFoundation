import Foundation
import Testing
@testable import SBJDataDefinition

@SBJStructure
private struct ValidatedSettings {
    @SBJDictionary(
        minCount: 1,
        key: [SBJStringRules(minLength: 2), SBJStringRules(maxLength: 20)],
        value: [SBJIntegerRules(min: 0), SBJIntegerRules(range: 0...100)]
    )
    var settings: [String: Int]
}

@Suite("Dictionary member snapshot rules")
struct SBJDictionaryMemberRuleTests {
    @Test func checksKeysAndValuesOnlyWhenInvoked() {
        let rules = ValidatedSettings.sbjProperties[0].constraints
        #expect(rules.contains(.dictionaryKeyRule(.string(SBJStringRules(minLength: 2)))))
        #expect(rules.contains(.dictionaryKeyRule(.string(SBJStringRules(maxLength: 20)))))
        #expect(rules.contains(.dictionaryValueRule(.integer(SBJIntegerRules(min: 0)))))
        #expect(rules.contains(.dictionaryValueRule(.integer(SBJIntegerRules(range: 0...100)))))
        let valid = ValidatedSettings(settings: ["alpha": 50])
        #expect(SBJInvariantCheck.validationError(valid, at: .root) == nil)
        let invalidKey = ValidatedSettings(settings: ["a": 50])
        #expect(SBJInvariantCheck.validationError(invalidKey, at: .root) != nil)
        let invalidValue = ValidatedSettings(settings: ["alpha": 105])
        #expect(SBJInvariantCheck.validationError(invalidValue, at: .root) != nil)
        #expect(invalidValue.settings["alpha"] == 105)
    }
}
