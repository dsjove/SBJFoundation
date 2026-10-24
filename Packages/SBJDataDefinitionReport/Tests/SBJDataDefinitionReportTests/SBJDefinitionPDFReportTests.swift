#if !os(watchOS) && canImport(UIKit) && canImport(PDFKit)
import Testing
import PDFKit
import SBJLayout
import SBJDataDefinition
@testable import SBJDataDefinitionReport

@SBJStructure
private struct PDFReportFixture: Codable {
    var title: String = "Recipe"
    var servings: Int = 4
}

@Suite("Definition PDF report")
struct SBJDefinitionPDFReportTests {
    @MainActor
    @Test func generatesHeadlessPDFAndSectionPositions() {
        let catalog = SBJDefinitionCatalog(PDFReportFixture.self)
        let result = SBJDefinitionPDFReport.makePDFResult(catalog: catalog)
        #expect(!result.data.isEmpty)
        #expect(result.document?.pageCount ?? 0 > 0)
        #expect(result.positions["type-0"] != nil)
    }

    @MainActor
    @Test func constructsNativeLayoutPDFPresentation() {
        let view = SBJDefinitionReportView(catalog: SBJDefinitionCatalog(PDFReportFixture.self))
        _ = view.body
    }
}
#endif
