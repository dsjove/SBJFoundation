#if !os(watchOS)
import PDFKit
import SwiftUI

/// Shared public PDF presentation API. Platform-specific PDFKit hosting is private.
@MainActor
public struct StablePDFView: View {
    private let document: PDFDocument
    private let controller: PDFViewController?
    private let layout: PDFPresentationLayout
    private let initialPageIndex: Int
    private let onReady: @MainActor () -> Void

    public init(
        document: PDFDocument,
        controller: PDFViewController? = nil,
        layout: PDFPresentationLayout = .verticalSinglePage,
        initialPageIndex: Int = 0,
        onReady: @escaping @MainActor () -> Void = {}
    ) {
        self.document = document
        self.controller = controller
        self.layout = layout
        self.initialPageIndex = max(initialPageIndex, 0)
        self.onReady = onReady
    }

    public var body: some View {
        StablePDFNativeView(
            document: document,
            controller: controller,
            layout: layout,
            initialPageIndex: initialPageIndex,
            onReady: onReady
        )
    }
}
#endif
