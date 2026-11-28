import Foundation
import SwiftUI
import Testing
import SBJStructure
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
        actions.remove?()
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
        actions.remove?()
        actions.moveUp?()
        #expect(values == ["first", "second"])
    }
}


extension SBJCollectionAndUnitInteractionTests {
    @Test("Array element field presentation filters rows without modifying values")
    func arrayElementPresentationTraversal() {
        let values = ["first", "second"]
        let hidden = SBJEditorValueTraversal.children(
            of: values, context: .root,
            elementPresentation: SBJFieldPresentationValue(exclude: true)
        )
        #expect(hidden.isEmpty)
        #expect(values == ["first", "second"])

        let visible = SBJEditorValueTraversal.children(
            of: values, context: .root,
            elementPresentation: SBJFieldPresentationValue(autoExpand: true)
        )
        #expect(visible.map(\.name) == ["", ""])
        #expect(visible.allSatisfy { $0.disclosureMode == .autoOpen })
        #expect(Set(visible.map(\.id)).count == 2)
        let bound = SBJEditorValueTraversal.boundChildren(of: Binding.constant(values), context: .root, registry: .init())
        #expect(bound.map(\.name) == ["", ""])
        #expect(bound.map(\.id) == visible.map(\.id))
    }
}


extension SBJCollectionAndUnitInteractionTests {
    @Test func collectionLeafLabels() {
        let registry = SBJEditorRegistry()
        let notes = ["first", "second"]
        let named = SBJEditorValueTraversal.boundChildren(of: Binding.constant(notes), context: .root, registry: registry, itemTitleKey: \String.self)
        #expect(named.map(\.name) == notes)
        #expect(named.allSatisfy { !$0.isDisclosure })
        let tags = Set(notes)
        let unnamedSet = SBJEditorValueTraversal.boundChildren(of: Binding.constant(tags), context: .root, registry: registry)
        #expect(unnamedSet.map(\.name) == ["", ""])
        let namedSet = SBJEditorValueTraversal.boundChildren(of: Binding.constant(tags), context: .root, registry: registry, itemTitleKey: \String.self)
        #expect(Set(namedSet.map(\.name)) == tags)
        #expect(namedSet.allSatisfy { !$0.isDisclosure })
        let values = ["key": "value"]
        let fallback = SBJEditorValueTraversal.boundChildren(of: Binding.constant(values), context: .root, registry: registry)
        #expect(fallback.map(\.name) == ["key"])
        let override = SBJEditorValueTraversal.boundChildren(of: Binding.constant(values), context: .root, registry: registry, itemTitleKey: \String.self)
        #expect(override.map(\.name) == ["value"])
        let hiddenKey = SBJEditorValueTraversal.boundChildren(of: Binding.constant(values), context: .root, registry: registry, dictionaryPresentation: .init(key: .init(exclude: true)))
        #expect(hiddenKey.map(\.name) == [""])
        #expect(fallback.map(\.id) == override.map(\.id))
        #expect(fallback.map(\.id) == hiddenKey.map(\.id))
        let nested = SBJEditorValueTraversal.boundChildren(of: Binding.constant([["first"]]), context: .root, registry: registry)
        #expect(nested.first?.isDisclosure == true)
    }
}
