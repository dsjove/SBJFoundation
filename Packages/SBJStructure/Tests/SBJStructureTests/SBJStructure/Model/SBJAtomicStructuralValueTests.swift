import Foundation
import Testing
@testable import SBJStructure

@SBJStructure
private struct AtomicMeasurementExample {
    @SBJUnitValue(min: 0)
    var distance = UnitValue<LengthUnit>(30, unit: .foot)
    var optionalDistance: UnitValue<LengthUnit>? = nil
}

@SBJStructure
private struct NamedExample {
    var name = "Fighter"
    var description = "A real property"
}

@SBJStructure(atomic: false)
private struct CompoundExample {
    var value = 1
}

@Suite struct SBJAtomicStructuralValueTests {
    @Test func atomicTypeKeepsItsCanonicalDefinition() {
        typealias Value = UnitValue<LengthUnit>
        #expect(SBJStructuralType.isAtomic(Value.self))
        #expect(SBJStructuralType.isAtomic(MixedUnitValue<LengthUnit>.self))
        #expect(SBJStructuralType.isAtomic(PairedUnitValue<LengthUnit>.self))
        #expect(!SBJStructuralType.isAtomic(UnitEditingPolicy<LengthUnit>.self))
        #expect(!SBJStructuralType.isAtomic(CompoundExample.self))
        #expect(SBJStructuralTraversal.definition(of: Value.self).map(\.sourceName) == ["value", "unit"])
        #expect(!Value(30, unit: .foot).sbjStructuralEquals(Value(31, unit: .foot)))
    }

    @Test func consumerTraversalStopsAtAtomicValueButValidationDoesNot() throws {
        var model = AtomicMeasurementExample()
        let occurrences = SBJStructuralTraversal.descendants(in: model)
        #expect(occurrences.map(\.identityPath) == [["property:distance"], ["property:optionalDistance"]])
        model.optionalDistance = .init(1, unit: .inch)
        #expect(SBJStructuralTraversal.descendants(in: model).count == 2)
        try model.invariant(at: .root)
        model.distance = .init(-1, unit: .foot)
        #expect(throws: (any Error).self) { try model.invariant(at: .root) }
    }

    @Test func mixedDisplayUsesBothComponents() {
        let height = MixedUnitValue(major: UnitValue(5, unit: LengthUnit.foot), minor: UnitValue(9, unit: LengthUnit.inch))
        #expect(height.presentedValue == "\(height.major.presentedValue) \(height.minor.presentedValue)")
    }

    @Test func declaredNameIsNotGeneratedOrConfusedWithDescription() {
        var item = NamedExample()
        #expect(SBJCollectionItemIdentification.hasDeclaredName(NamedExample.self))
        #expect(SBJCollectionItemIdentification.declaredName(for: item) == "Fighter")
        #expect(SBJCollectionItemIdentification.arrayTitle(for: item, index: 0) == "Fighter")
        #expect(NamedExample.sbjProperties.map(\.sourceName) == ["name", "description"])
        item.name = ""
        #expect(SBJCollectionItemIdentification.hasDeclaredName(NamedExample.self))
        #expect(SBJCollectionItemIdentification.declaredName(for: item) == nil)
        #expect(SBJCollectionItemIdentification.arrayTitle(for: item, index: 0) == "[0]")
        #expect(!SBJCollectionItemIdentification.hasDeclaredName(CompoundExample.self))
    }

    @Test func optionalPresenceIsIndependentOfContent() {
        let absent: String? = nil
        let empty: String? = ""
        let nested: String?? = .some(nil)
        #expect(SBJStructuralType.optionalPresence(of: absent as Any) == .notSet)
        #expect(SBJStructuralType.optionalPresence(of: empty as Any) == .set)
        #expect(SBJStructuralType.optionalPresence(of: nested as Any) == .set)
        #expect(SBJStructuralType.optionalPresence(of: "") == .notOptional)
        #expect(SBJOptionalPresence.notSet.count == 0)
        #expect(SBJOptionalPresence.set.count == 1)
    }
}
