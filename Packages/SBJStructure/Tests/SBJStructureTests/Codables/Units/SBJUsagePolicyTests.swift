import Testing
@testable import SBJStructure

@Suite struct SBJUsagePolicyTests {
    @Test func arrayRestrictionsApplyToEditorOperations() {
        let hints: [SBJPropertyHint] = [.arrayPresentation(.init(insertable: false, removable: true, reorderable: false))]
        let supported: Set<SBJCollectionOperationKind> = [.append, .insert, .duplicate, .remove, .move, .replace]
        #expect(SBJUsagePolicy.allowedCollectionOperations(supported, hints: hints) == [.remove, .replace])
    }

    @Test func hiddenFieldIsStillReportable() {
        let hints: [SBJPropertyHint] = [.fieldPresentation(.init(exclude: true))]
        #expect(SBJUsagePolicy.isPresentationExcluded(hints))
    }

    @Test func unitConstraintsOverrideEditableDefaults() {
        #expect(SBJUsagePolicy.canChangeUnit([]))
        #expect(!SBJUsagePolicy.canChangeUnit([.unitMutable(false)]))
        #expect(!SBJUsagePolicy.canChangeUnit([.requiredUnit(SBJDefaultUnit(LengthUnit.inch))]))
    }
}
