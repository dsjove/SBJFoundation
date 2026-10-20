import SBJUIVocabulary
import Foundation
import SBJDataDefinition
import Testing
@testable import SBJFoundation

struct SBJSwiftEncoderFoundationTests {
    @Test func exportsUnitValueUsingItsDesignatedInitializerLabels() {
        let source = SBJSwiftEncoder().expression(
            for: UnitValue<LengthUnit>(68, unit: .inch)
        )
        #expect(source == ".init(\n\t// Numeric amount expressed in the selected unit.\n\t68.0,\n\t// Measurement unit used by this value.\n\tunit: .inch\n)")
    }

}
