import Testing
@testable import SBJStructure

@Suite struct SBJUsagePolicyTests {
    @Test func arrayRestrictionsApplyToBothEditorsButNotReports() {
        let hints: [SBJPropertyHint] = [.arrayPresentation(.init(insertable: false, removable: true, reorderable: false))]
        let supported: Set<SBJCollectionOperationKind> = [.append, .insert, .duplicate, .remove, .move, .replace]
        for consumer in [SBJUsageConsumer.visualEditor, .semanticEditor] {
            let allowed = SBJUsagePolicy.allowedCollectionOperations(supported, hints: hints, consumer: consumer)
            #expect(allowed == [.remove, .replace])
        }
        #expect(SBJUsagePolicy.allowedCollectionOperations(supported, hints: hints, consumer: .report) == supported)
    }

    @Test func hiddenFieldIsStillReportable() {
        let hints: [SBJPropertyHint] = [.fieldPresentation(.init(exclude: true))]
        #expect(!SBJUsagePolicy.isVisible(hints, to: .visualEditor))
        #expect(!SBJUsagePolicy.isVisible(hints, to: .semanticEditor))
        #expect(SBJUsagePolicy.isVisible(hints, to: .report))
    }

    @Test func unitConstraintsOverrideEditableDefaults() {
        #expect(SBJUsagePolicy.canChangeUnit([]))
        #expect(!SBJUsagePolicy.canChangeUnit([.unitMutable(false)]))
        #expect(!SBJUsagePolicy.canChangeUnit([.requiredUnit(SBJDefaultUnit(LengthUnit.inch))]))
    }
}
