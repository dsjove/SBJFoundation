import Testing
@testable import SBJLayout
import SBJUnits

struct PageLayoutUnitValueTests {
    @Test func pdfPointMarginsUseSharedLengthConversion() {
        let margin = UnitValue<LengthUnit>(72, unit: .point)
        #expect(abs(margin.converted(to: .inch).value - 1) < 0.000_001)
        #expect(abs(margin.converted(to: .millimeter).value - 25.4) < 0.000_001)
    }
}

extension PageLayoutUnitValueTests {
    @Test func pageLayoutExposesPhysicalDimensionsAsUnitValues() {
        let page = PageLayout(pageSize: .letter)
#expect(page.pageRect.width == 612)
        #expect(page.pageRect.height == 792)
        #expect(abs(page.printableRect.width - 576) < 0.000_001)
        #expect(abs(page.printableRect.height - 756) < 0.000_001)
    }
}
