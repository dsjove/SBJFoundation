import Foundation
import Testing
@testable import SBJDataDefinition

@Test func pairedUnitsConvertBothComponents() throws {
    let pair = PairedUnitValue<LengthUnit>(30, 120, unit: .foot)
    let inches = pair.converted(to: .inch)
    #expect(inches.first == 360)
    #expect(inches.second == 1440)
    #expect(inches.unit == .inch)
    let copy = try JSONDecoder().decode(PairedUnitValue<LengthUnit>.self,
                                        from: JSONEncoder().encode(pair))
    #expect(copy == pair)
}
