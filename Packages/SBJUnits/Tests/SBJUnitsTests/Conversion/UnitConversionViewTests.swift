import Testing
@testable import SBJUnits

@Suite("Unit conversion views")
struct UnitConversionViewTests {
    @MainActor
    @Test func conversionViewsRetainSharedPublicSurface() {
        let model = UnitConversionModel(
            source: UnitValue<VolumeUnit>(1, unit: .cup),
            destinationUnit: .liter
        )

        _ = UnitConversionView(model: model)
        _ = ConversionView()
    }
}
