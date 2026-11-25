import Testing
import SBJStructure

@SBJStructure
private struct ConditionalBehavior {
    var value: Int = 0
    #if swift(>=6.0)
    func method() -> Int { value }
    var computed: Int { value + 1 }
    static let constant = 1
    #if DEBUG
    struct Nested { var stored: Int = 0 }
    #else
    func otherMethod() {}
    #endif
    #else
    func fallback() {}
    #endif
}

// An intentional warning: the generator cannot enumerate conditional storage.
@SBJStructure
private struct ConditionalStorage {
    var value: Int = 0
    #if swift(>=6.0)
    #if DEBUG
    var hidden: Int = 1
    #else
    var other: Int = 2
    #endif
    #endif
}

@Test func conditionalBehaviorDoesNotInvalidateStoredState() {
    #expect(ConditionalBehavior.sbjHasCompleteStoredDefinition)
    #expect(ConditionalBehavior(value: 1).sbjStructuralEquals(.init(value: 1)))
    #expect(!ConditionalBehavior(value: 1).sbjStructuralEquals(.init(value: 2)))
}

@Test func conditionalStorageRemainsConservative() {
    #expect(!ConditionalStorage.sbjHasCompleteStoredDefinition)
    let value = ConditionalStorage()
    #expect(!value.sbjStructuralEquals(value))
}
