#if !os(watchOS)
import PDFKit
import SwiftUI
import Testing
@testable import SBJLayout

@MainActor
@Suite("StablePDFView cross-platform API")
struct StablePDFViewAPITests {
    @Test("Shared initializer supports both existing and explicit page selection")
    func initializerParity() {
        let document = PDFDocument()
        let defaultView = StablePDFView(document: document)
        let explicitView = StablePDFView(
            document: document,
            layout: .adaptive(),
            initialPageIndex: 2,
            onReady: {}
        )
        _ = defaultView
        _ = explicitView
    }
}
#endif
