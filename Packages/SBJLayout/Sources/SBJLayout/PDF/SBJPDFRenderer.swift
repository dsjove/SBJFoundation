#if !os(watchOS)
import CoreGraphics
import Foundation
#if os(macOS)
import AppKit

/// Small CoreGraphics bridge; PDFGenerator and the pagination engine stay shared.
struct SBJPDFRendererFormat {
    var documentInfo: [String: Any] = [:]
}

final class SBJPDFRenderer {
    let bounds: CGRect
    let format: SBJPDFRendererFormat
    init(bounds: CGRect, format: SBJPDFRendererFormat) {
        self.bounds = bounds
        self.format = format
    }

    final class Context {
        let graphics: CGContext
        let bounds: CGRect
        var pageStarted = false
        init(graphics: CGContext, bounds: CGRect) { self.graphics = graphics; self.bounds = bounds }
        func beginPage() {
            if pageStarted { graphics.endPDFPage() }
            pageStarted = true
            graphics.beginPDFPage(nil)
            // Pagination measures from the upper-left, matching the iOS renderer.
            graphics.translateBy(x: 0, y: bounds.height)
            graphics.scaleBy(x: 1, y: -1)
            NSGraphicsContext.current = NSGraphicsContext(cgContext: graphics, flipped: true)
        }
    }

    func pdfData(_ body: (Context) -> Void) -> Data {
        let data = NSMutableData()
        var mediaBox = bounds
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let graphics = CGContext(consumer: consumer, mediaBox: &mediaBox, format.documentInfo as CFDictionary)
        else { return Data() }
        let previous = NSGraphicsContext.current
        let context = Context(graphics: graphics, bounds: bounds)
        // beginPage calls are issued by the existing pagination callback. The
        // context owns page lifecycle while preserving the drawing context.
        body(context)
        if context.pageStarted { graphics.endPDFPage() }
        graphics.closePDF()
        NSGraphicsContext.current = previous
        return data as Data
    }
}
#else
import UIKit
typealias SBJPDFRendererFormat = UIGraphicsPDFRendererFormat
typealias SBJPDFRenderer = UIGraphicsPDFRenderer
#endif
#endif
