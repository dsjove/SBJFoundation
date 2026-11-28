import Foundation
import SwiftUI
import Testing
import SBJStructure
@testable import SBJStructuredEditor

#if !os(tvOS) && !os(watchOS)
@SBJStructure
private struct EnhancedConstraintEditorFixture {
    @SBJInteger(min: 1, max: 20) var score: Int = 10
    @SBJNumber(max: 10) var number: Double = 5
    @SBJString(allowedValues: ["Small", "Large"], pattern: "[A-Za-z]+") var size: String = "Small"
    @SBJUnitValue(min: 2) var mass: UnitValue<MassUnit> = .init(3, unit: .gram)
    @SBJDictionary(key: [SBJStringRules(allowedValues: ["one", "two"])], value: [SBJIntegerRules(min: 1, max: 20)])
    var scores: [String: Int] = ["one": 10]
}

@MainActor @Test func editorConfigurationConsumesEnhancedConstraints() throws {
    let type = EnhancedConstraintEditorFixture.self
    let integer = SBJEditFieldConfiguration(metadata: type.propertyMetadata(for: \.score))
    #expect(integer.integerRange == 1...20)
    let number = SBJEditFieldConfiguration(metadata: type.propertyMetadata(for: \.number))
    #expect(number.numberRange == -Double.greatestFiniteMagnitude...10)
    let text = SBJEditFieldConfiguration(metadata: type.propertyMetadata(for: \.size))
    #expect(text.constraintProjection.allowedStrings == ["Small", "Large"])
    #expect(!text.constraintProjection.acceptsString("large"))
    let mass = SBJEditFieldConfiguration(metadata: type.propertyMetadata(for: \.mass))
    #expect(mass.constraintProjection.unitMinimum == 2)
    let dictionary = SBJEditFieldConfiguration(metadata: type.propertyMetadata(for: \.scores))
    #expect(dictionary.constraintProjection.dictionaryKey.allowedStrings == ["one", "two"])
    #expect(dictionary.constraintProjection.dictionaryValue.integerRange == 1...20)
}

private struct DictionaryCreationFixture { var values: [String: String] = [:] }

@MainActor @Test func finiteDictionaryKeysUseUnusedChoices() {
    let registry = SBJEditorRegistry()
    let keys = SBJConstraintProjection([.stringRules(.init(allowedValues: ["one", "two"]))])
    let values = SBJConstraintProjection([.stringRules(.init(allowedValues: ["yes", "no"]))])
    let stringGenerator = SBJDictionaryKeyGenerator(for: \DictionaryCreationFixture.values) { dictionary, value in
        ["one", "two"].first { !dictionary.keys.contains($0) }
    }
    let entry = registry.createDictionaryEntry(key: String.self, value: String.self,
        existing: ["one": "yes"], generator: stringGenerator, keyConstraints: keys, valueConstraints: values)
    #expect(entry?.0 == "two")
    #expect(entry?.1 == "yes")
    let exhausted = registry.createDictionaryEntry(key: String.self, value: String.self,
        existing: ["one": "yes", "two": "no"], generator: stringGenerator, keyConstraints: keys, valueConstraints: values)
    #expect(exhausted == nil)
}

@MainActor @Test func constrainedDictionaryUsesOnlyValueRows() {
    let binding = Binding.constant(["one": 10])
    let constraints = SBJConstraintProjection([
        .dictionaryKeyRule(.string(.init(allowedValues: ["one", "two"]))),
        .dictionaryValueRule(.integer(.init(min: 1, max: 20)))
    ])
    let rows = SBJEditorValueTraversal.boundChildren(of: binding, context: .root, registry: .init(), constraints: constraints)
    #expect(rows.count == 1)
    #expect(rows.first?.name == "one")
    #expect(rows.first?.isDisclosure == false)
    #expect(Set(rows.map(\.id)).count == rows.count)
    let readOnlyKeys = SBJEditorValueTraversal.boundChildren(of: binding, context: .root, registry: .init(), constraints: constraints, removable: false)
    #expect(readOnlyKeys.count == 1)
    #expect(readOnlyKeys.first?.name == "one")
}

@MainActor @Test func finiteStringCreationUsesDeclaredChoices() {
    let registry = SBJEditorRegistry()
    let choices = SBJConstraintProjection([.stringRules(.init(allowedValues: ["Small", "Large"]))])
    #expect(registry.create(String.self, constraints: choices) == "Small")
    #expect(registry.createArrayElement(String.self, existing: [], constraints: choices) == "Small")
    #expect(registry.createSetElement(String.self, existing: ["Small"], constraints: choices) == "Large")
    #expect(registry.createSetElement(String.self, existing: ["Small", "Large"], constraints: choices) == nil)
}

#endif
