#if os(macOS)
import AppKit
import PDFKit
import SwiftUI

/// Native PDFKit host. The view identity persists when its PDF document changes.
@MainActor
public struct StablePDFView: NSViewRepresentable {
    public var document: PDFDocument
    public var controller: PDFViewController?
    public var layout: PDFPresentationLayout
    public var initialPageIndex: Int
    public var onReady: (() -> Void)?

    public init(document: PDFDocument, controller: PDFViewController? = nil,
                layout: PDFPresentationLayout = .adaptive(), initialPageIndex: Int = 0,
                onReady: (() -> Void)? = nil) {
        self.document = document
        self.controller = controller
        self.layout = layout
        self.initialPageIndex = initialPageIndex
        self.onReady = onReady
    }

    public func makeNSView(context: Context) -> FitClampedPDFView {
        let view = FitClampedPDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = document
        if let page = document.page(at: initialPageIndex) { view.go(to: page) }
        controller?.attach(view)
        onReady?()
        return view
    }

    public func updateNSView(_ view: FitClampedPDFView, context: Context) {
        controller?.attach(view)
        if view.document !== document {
            let previousIndex = view.document.flatMap { old -> Int? in
                guard let page = view.currentPage else { return nil }
                return old.index(for: page)
            } ?? initialPageIndex
            let previousScale = view.scaleFactor
            view.document = document
            if let page = document.page(at: min(max(previousIndex, 0), max(document.pageCount - 1, 0))) {
                view.go(to: page)
            }
            if previousScale > 0 { view.scaleFactor = max(view.minScaleFactor, previousScale) }
            onReady?()
        }
        let pageSize = document.page(at: 0)?.bounds(for: .cropBox).size ?? .zero
        switch layout {
        case .verticalSinglePage: view.displayMode = .singlePageContinuous
        case .horizontalSinglePage: view.displayMode = .singlePage
        case .horizontalTwoPage: view.displayMode = .twoUp
        case let .adaptive(policy):
            view.displayMode = policy.displayMode(viewport: view.bounds.size, pageSize: pageSize, current: view.displayMode)
        }
        controller?.refreshPageState()
    }

    public static func dismantleNSView(_ view: FitClampedPDFView, coordinator: ()) { }
}

@MainActor
public final class FitClampedPDFView: PDFView {
    func clearSearchPresentation() { highlightedSelections = nil }
    func presentSearchMatches(_ matches: [PDFSearchMatch], style: PDFSearchPresentationStyle) {
        guard let document else { return }
        highlightedSelections = matches.compactMap { match in
            guard let first = match.firstFragment,
                  let page = document.page(at: first.pageIndex) else { return nil }
            return page.selection(for: first.pageRect)
        }
    }
    func animateSearchMatch(_ match: PDFSearchMatch) { }
}

extension PDFView {
    var sbjLogicalPageIndex: Int? {
        guard let page = currentPage else { return nil }
        return document?.index(for: page)
    }
    func go(to position: PaginationPosition) {
        guard let page = document?.page(at: position.pageIndex) else { return }
        let b = page.bounds(for: displayBox)
        let pageRect = position.pageRect
        guard pageRect.width > 0, pageRect.height > 0 else { return }
        let frame = position.frame
        let converted = CGRect(x: b.minX + (frame.minX-pageRect.minX)/pageRect.width*b.width,
                               y: b.maxY - (frame.maxY-pageRect.minY)/pageRect.height*b.height,
                               width: frame.width/pageRect.width*b.width,
                               height: frame.height/pageRect.height*b.height)
        go(to: converted, on: page)
    }
}
#endif
