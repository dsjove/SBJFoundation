import SBJUIVocabulary
import SwiftUI
import SBJDataDefinition
import Testing
@testable import SBJFoundation

struct SBJTypeErasureTests {
    @MainActor
    @Test func anyBindingErasesOnceAndRecoversTypedBinding() {
        var storage = 12
        let source = Binding<Int>(
            get: { storage },
            set: { storage = $0 }
        )

        let erased = SBJAnyBinding(source)
        #expect(ObjectIdentifier(erased.valueType) == ObjectIdentifier(Int.self))

        let recovered = erased.binding(as: Int.self)
        #expect(recovered.wrappedValue == 12)

        recovered.wrappedValue = 42
        #expect(storage == 42)
    }

    @Test func originalValueRecordsAndRecoversItsConcreteType() {
        let erased = SBJEditorOriginalValue("before")
        #expect(ObjectIdentifier(erased.valueType) == ObjectIdentifier(String.self))
        #expect(erased.value(as: String.self) == "before")
    }
}
