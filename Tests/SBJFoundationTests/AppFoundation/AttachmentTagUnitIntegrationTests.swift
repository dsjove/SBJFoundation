import Foundation
import SBJDataDefinition
import Testing
@testable import SBJFoundation

@Suite("Attachment, tag, and unit integration")
@MainActor
struct AttachmentTagUnitIntegrationTests {
    @Test
    func unitModelsExposePropertyInformation() {
        #expect(UnitValue<LengthUnit>.propertyInfo(for: \UnitValue<LengthUnit>.value) != nil)
        #expect(UnitValue<LengthUnit>.propertyInfo(for: \UnitValue<LengthUnit>.unit) != nil)
        #expect(UnitConversionModel<LengthUnit>.propertyInfo(for: \UnitConversionModel<LengthUnit>.source) != nil)
        #expect(UnitConversionModel<LengthUnit>.propertyInfo(for: \UnitConversionModel<LengthUnit>.destinationUnit) != nil)
    }
}
