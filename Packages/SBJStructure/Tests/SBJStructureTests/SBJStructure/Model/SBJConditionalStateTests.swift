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

// Private storage is intentionally absent from the public structural definition,
// but must still participate in stored-state comparison.
@SBJStructure
private struct HiddenStorage {
    var value: Int = 0
    private var hidden: Int

    init(hidden: Int) { self.hidden = hidden }
}

@Test func conditionalBehaviorDoesNotInvalidateStoredState() {
    #expect(ConditionalBehavior.sbjHasCompleteStoredDefinition)
    #expect(ConditionalBehavior(value: 1).sbjStructuralEquals(.init(value: 1)))
    #expect(!ConditionalBehavior(value: 1).sbjStructuralEquals(.init(value: 2)))
}

@Test func incompletePublicDefinitionStillComparesPrivateState() {
    #expect(!HiddenStorage.sbjHasCompleteStoredDefinition)
    let value = HiddenStorage(hidden: 1)
    #expect(value.sbjStructuralEquals(value))
    #expect(!value.sbjStructuralEquals(HiddenStorage(hidden: 2)))
}
