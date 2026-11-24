#if !os(watchOS)
import Testing
@testable import SBJLayout

@Suite("PDF page navigation bounds")
struct PDFPageNavigationTests {
    @Test func forwardNavigationAtIntegerLimitsDoesNotOverflow() {
        let lastPage = PDFCurrentPage(pageNumber: Int.max, displayCount: Int.max, pageCount: Int.max)
        #expect(!lastPage.canGoForward)
        #expect(lastPage.description == "\(Int.max)/\(Int.max)")

        let firstPage = PDFCurrentPage(pageNumber: 1, displayCount: Int.max, pageCount: Int.max)
        #expect(!firstPage.canGoForward)
    }

    @Test func forwardNavigationRespectsDisplayedPageSpan() {
        #expect(PDFCurrentPage(pageNumber: 2, displayCount: 2, pageCount: 5).canGoForward)
        #expect(!PDFCurrentPage(pageNumber: 4, displayCount: 2, pageCount: 5).canGoForward)
    }
}
#endif
