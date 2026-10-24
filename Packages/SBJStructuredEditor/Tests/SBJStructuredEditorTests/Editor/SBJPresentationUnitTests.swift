import SBJDataDefinition
import Testing
@testable import SBJStructuredEditor

@SBJStructure
private struct UnitPresentationFixture: Codable {
    @SBJPresentationUnit(.editable)
    var amount = UnitValue<LengthUnit>(3, unit: .meter)
    @SBJPresentationUnit(.fixedUnit)
    var fixed = UnitValue<LengthUnit>(4, unit: .foot)
}

@MainActor
struct SBJPresentationUnitTests {
    @Test func unitPresentationIsExposedThroughStructureMetadata() {
        let editable = UnitPresentationFixture.propertyMetadata(for: \.amount)
        let fixed = UnitPresentationFixture.propertyMetadata(for: \.fixed)
        #expect(editable?.hints.contains(.presentationUnit(.editable)) == true)
        #expect(fixed?.hints.contains(.presentationUnit(.fixedUnit)) == true)
        #expect(SBJEditFieldConfiguration(metadata: editable).unitEditor == .editable)
        #expect(SBJEditFieldConfiguration(metadata: fixed).unitEditor == .fixedUnit)
    }
}
