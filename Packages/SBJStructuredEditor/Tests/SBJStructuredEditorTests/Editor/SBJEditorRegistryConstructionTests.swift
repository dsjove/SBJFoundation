import Foundation
import SBJDataDefinition
import Testing
@testable import SBJStructuredEditor

private struct RegistryCustomValue: Equatable {
    var value: Int
}

private struct RegistryExhaustibleValue: Equatable, SBJCollectionElementCreatable {
    let index: Int

    static func sbjCreateValue(existing: [Self]) -> Self? {
        let used = Set(existing.map(\.index))
        guard let next = (0...1).first(where: { !used.contains($0) }) else { return nil }
        return .init(index: next)
    }
}

struct SBJEditorRegistryConstructionTests {
    @Test func registeredCreatorProducesExactType() {
        var registry = SBJEditorRegistry()
        registry.registerCreator(RegistryCustomValue.self) { .init(value: 7) }
        #expect(registry.create(RegistryCustomValue.self) == .init(value: 7))
        #expect(registry.create(String.self) == "")
    }

    @Test func collectionAwareCreationUsesExistingValuesAndHonorsExhaustion() {
        var registry = SBJEditorRegistry()
        registry.registerCreator(RegistryExhaustibleValue.self) { .init(index: 999) }
        #expect(registry.createArrayElement(RegistryExhaustibleValue.self, existing: [.init(index: 0)]) == .init(index: 1))
        #expect(registry.createArrayElement(RegistryExhaustibleValue.self, existing: [.init(index: 0), .init(index: 1)]) == nil)
    }
}

private enum RegistryFiniteKey: String, Codable, CaseIterable {
    case first, second, third
}

struct SBJFiniteContainerCreationTests {
    @Test func setCreationSelectsFirstUnusedCaseAndStopsAtExhaustion() {
        let registry = SBJEditorRegistry()
        #expect(registry.createSetElement(RegistryFiniteKey.self, existing: [.first]) == .second)
        #expect(registry.createSetElement(RegistryFiniteKey.self, existing: [.first, .second]) == .third)
        #expect(registry.createSetElement(RegistryFiniteKey.self, existing: Set(RegistryFiniteKey.allCases)) == nil)
    }

    @Test func dictionaryCreationSelectsFirstUnusedKey() {
        let registry = SBJEditorRegistry()
        let existing: [RegistryFiniteKey: Int] = [.first: 11, .third: 33]
        let entry = registry.createDictionaryEntry(key: RegistryFiniteKey.self, value: Int.self, existing: existing)
        #expect(entry?.0 == .second)
        #expect(entry?.1 == 0)
        #expect(registry.createDictionaryEntry(key: RegistryFiniteKey.self, value: Int.self,
            existing: [.first: 1, .second: 2, .third: 3]) == nil)
    }

    @Test func dictionaryCreationRequiresConstructibleValue() {
        let registry = SBJEditorRegistry()
        #expect(registry.createDictionaryEntry(key: RegistryFiniteKey.self,
            value: RegistryCustomValue.self, existing: [RegistryFiniteKey: RegistryCustomValue]()) == nil)
    }

    @Test func nonCaseIterableSetAndDictionaryRetainDefaultPolicy() {
        let registry = SBJEditorRegistry()
        #expect(registry.createSetElement(String.self, existing: []) == "")
        #expect(registry.createSetElement(String.self, existing: [""]) == nil)
        #expect(registry.createDictionaryEntry(key: String.self, value: Int.self,
            existing: [String: Int]())?.0 == "")
        #expect(registry.createDictionaryEntry(key: String.self, value: Int.self,
            existing: ["": 1]) == nil)
    }

    @Test func dictionaryValueUsesRegisteredCreator() {
        var registry = SBJEditorRegistry()
        registry.registerCreator(RegistryCustomValue.self) { .init(value: 99) }
        #expect(registry.createDictionaryEntry(key: RegistryFiniteKey.self,
            value: RegistryCustomValue.self,
            existing: [RegistryFiniteKey: RegistryCustomValue]())?.1 == .init(value: 99))
    }
}
