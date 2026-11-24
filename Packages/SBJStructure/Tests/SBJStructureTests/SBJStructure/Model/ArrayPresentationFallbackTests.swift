import Testing
@testable import SBJStructure

private struct PresentableItem: SBJTextPresentable {
    let presentedValue: String
}

@Test func arrayUsesPresentableTitleWithoutExplicitAnnotation() {
    #expect(SBJCollectionItemIdentification.arrayTitle(for: PresentableItem(presentedValue: "Armor"), index: 0) == "Armor")
    #expect(SBJCollectionItemIdentification.arrayTitle(for: PresentableItem(presentedValue: ""), index: 2) == "[2]")
}
