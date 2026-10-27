import Foundation
import SwiftUI
import Testing
import SBJDataDefinition
@testable import SBJStructuredEditor

@MainActor
@Suite("Collection and unit interaction contracts")
struct SBJCollectionAndUnitInteractionTests {
    @Test("Mixed and paired units are editor-atomic, even when optional")
    func atomicUnitTraversal() {
        let mixed = MixedUnitValue<LengthUnit>(
            major: .init(5, unit: .foot),
            minor: .init(9, unit: .inch)
        )
        let paired = PairedUnitValue<LengthUnit>(20, 60, unit: .foot)
        #expect(SBJEditorValueTraversal.children(of: mixed, context: .root).isEmpty)
        #expect(SBJEditorValueTraversal.children(of: paired, context: .root).isEmpty)
        let optionalMixed: MixedUnitValue<LengthUnit>? = mixed
        let optionalPaired: PairedUnitValue<LengthUnit>? = paired
        #expect(SBJEditorValueTraversal.children(of: optionalMixed, context: .root).isEmpty)
        #expect(SBJEditorValueTraversal.children(of: optionalPaired, context: .root).isEmpty)
    }

    @Test("Array item actions resolve the live position, not their initial slot")
    func removeMovedItemByLiveIndex() {
        var values = ["first", "second", "third"]
        var livePosition: Int? = 1
        let binding = Binding<[String]>(get: { values }, set: { values = $0 })
        let actions = SBJArrayElementActions.make(
            parent: binding, index: 1, count: values.count,
            canReorder: true, resolvedIndex: { livePosition }
        )
        livePosition = 2
        actions.remove()
        #expect(values == ["first", "second"])
    }

    @Test("An invalid live array position cannot mutate another element")
    func invalidLivePositionIsSafe() {
        var values = ["first", "second"]
        let binding = Binding<[String]>(get: { values }, set: { values = $0 })
        let actions = SBJArrayElementActions.make(
            parent: binding, index: 1, count: 2,
            canReorder: true, resolvedIndex: { 99 }
        )
        actions.remove()
        actions.moveUp?()
        #expect(values == ["first", "second"])
    }
}
