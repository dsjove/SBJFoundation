#if os(macOS)
import AppKit
import PDFKit
import SwiftUI

/// Thin AppKit bridge for the shared `StablePDFView` API.
@MainActor
struct StablePDFNativeView: NSViewRepresentable {
    let document: PDFDocument
    let controller: PDFViewController?
    let layout: PDFPresentationLayout
    let initialPageIndex: Int
    let onReady: @MainActor () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    func makeNSView(context: Context) -> FitClampedPDFView {
        let view = FitClampedPDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        configure(layout, on: view, document: document)
        view.document = document
        let index = controller.flatMap { $0.currentPage.pageNumber > 0 ? $0.currentPage.pageNumber - 1 : nil } ?? initialPageIndex
        if let page = document.page(at: max(index, 0)) { view.go(to: page) }
        context.coordinator.controller = controller
        controller?.attach(view)
        controller?.setDisplayCount(view.displayMode == .twoUp ? 2 : 1)
        controller?.documentDidChange()
        onReady()
        return view
    }

    func updateNSView(_ view: FitClampedPDFView, context: Context) {
        if context.coordinator.controller !== controller {
            context.coordinator.controller?.detach(view)
            context.coordinator.controller = controller
        }
        controller?.attach(view)
        if view.document !== document {
            let previousIndex = view.document.flatMap { old -> Int? in
                guard let page = view.currentPage else { return nil }
                let index = old.index(for: page)
                return index == NSNotFound ? nil : index
            } ?? initialPageIndex
            let previousScale = view.scaleFactor
            controller?.documentWillChange()
            configure(layout, on: view, document: document)
            view.document = document
            if let page = document.page(at: min(max(previousIndex, 0), max(document.pageCount - 1, 0))) {
                view.go(to: page)
            }
            if previousScale.isFinite && previousScale > 0 {
                view.scaleFactor = min(max(view.minScaleFactor, previousScale), view.maxScaleFactor)
            }
            controller?.refreshPageState()
            controller?.documentDidChange()
            onReady()
        } else {
            configure(layout, on: view, document: document)
            controller?.refreshPageState()
        }
        controller?.setDisplayCount(view.displayMode == .twoUp ? 2 : 1)
    }

    static func dismantleNSView(_ view: FitClampedPDFView, coordinator: Coordinator) {
        coordinator.controller?.detach(view)
    }

    final class Coordinator {
        var controller: PDFViewController?
        init(controller: PDFViewController?) { self.controller = controller }
    }

    private func configure(_ layout: PDFPresentationLayout, on view: FitClampedPDFView, document: PDFDocument) {
        let pageSize = document.page(at: 0)?.bounds(for: .cropBox).size ?? .zero
        switch layout {
        case .verticalSinglePage: view.displayMode = .singlePageContinuous
        case .horizontalSinglePage: view.displayMode = .singlePage
        case .horizontalTwoPage: view.displayMode = .twoUp
        case let .adaptive(policy):
            view.displayMode = policy.displayMode(viewport: view.bounds.size, pageSize: pageSize, current: view.displayMode)
        }
    }
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
