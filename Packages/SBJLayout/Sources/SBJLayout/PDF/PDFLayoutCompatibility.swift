#if !os(watchOS)
import PDFKit

@MainActor
extension PDFView {
    func sbjLayoutIfNeeded() {
        #if os(macOS)
        layoutSubtreeIfNeeded()
        #else
        layoutIfNeeded()
        #endif
    }
}
#endif
