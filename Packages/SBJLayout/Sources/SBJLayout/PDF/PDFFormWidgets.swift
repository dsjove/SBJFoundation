#if !os(watchOS)
import Foundation
import UIKit
import PDFKit

/// PDF-specific behavior; the graphical appearance remains the responsibility of the JCS control.
public struct JCSFormTraits {
    public var required: Bool
    public var readOnly: Bool
    public var maximumLength: Int?

    public init(required: Bool = false, readOnly: Bool = false, maximumLength: Int? = nil) {
        self.required = required
        self.readOnly = readOnly
        self.maximumLength = maximumLength
    }
}

internal enum PDFFormWidgetKind {
    case text(String, multiline: Bool, font: UIFont, color: UIColor, alignment: NSTextAlignment)
    case checkbox(Bool)
    case radio(value: String, selected: Bool)
}

internal struct PDFFormWidget {
    let name: String
    let bounds: CGRect // UIKit top-origin page geometry, resolved after pagination.
    let sourcePage: Int
    let kind: PDFFormWidgetKind
    let traits: JCSFormTraits
}

/// Operation-scoped collector. No state is shared between PDF generation calls.
internal final class PDFFormCollector: @unchecked Sendable {
    var widgets: [PDFFormWidget] = []
    var pageOrder: [Int] = []
    func pageBegan(_ sourcePage: Int) { pageOrder.append(sourcePage) }
    func add(_ name: String, bounds: CGRect, kind: PDFFormWidgetKind, traits: JCSFormTraits) {
        guard let page = RenderableEnvironment.context.page?.index else { return }
        widgets.append(.init(name: name, bounds: bounds, sourcePage: page, kind: kind, traits: traits))
    }
}

internal enum PDFFormEnvironment {
    @TaskLocal static var collector: PDFFormCollector?
}

internal enum PDFFormWriter {
    static func install(_ collector: PDFFormCollector, in document: PDFDocument) {
        let pageIndices = Dictionary(uniqueKeysWithValues: collector.pageOrder.enumerated().map { ($0.element, $0.offset) })
        for widget in collector.widgets {
            guard let index = pageIndices[widget.sourcePage],
                  let page = document.page(at: index) else { continue }
            let media = page.bounds(for: .mediaBox)
            let translated = CGRect(x: media.minX + widget.bounds.minX,
                                    y: media.maxY - widget.bounds.maxY,
                                    width: widget.bounds.width,
                                    height: widget.bounds.height)
            guard translated.width > 0, translated.height > 0 else { continue }
            let annotation = PDFAnnotation(bounds: translated, forType: .widget, withProperties: nil)
            // Configure the widget subtype before assigning its field identity.
            // PDFKit may rebuild the widget dictionary when its subtype changes.
            switch widget.kind {
            case let .text(value, multiline, font, color, alignment):
                annotation.widgetFieldType = .text
                annotation.widgetStringValue = value
                annotation.isMultiline = multiline
                annotation.font = font
                annotation.fontColor = color
                annotation.alignment = alignment
                if let maximumLength = widget.traits.maximumLength {
                    annotation.maximumLength = maximumLength
                }
            case let .checkbox(checked):
                annotation.widgetFieldType = .button
                annotation.widgetControlType = .checkBoxControl
                annotation.buttonWidgetState = checked ? .onState : .offState
            case let .radio(value, selected):
                annotation.widgetFieldType = .button
                annotation.widgetControlType = .radioButtonControl
                annotation.buttonWidgetStateString = value
                annotation.buttonWidgetState = selected ? .onState : .offState
            }
            annotation.fieldName = widget.name
            annotation.isReadOnly = widget.traits.readOnly
            // Keep the JCS-drawn border rather than draw a second PDFKit border.
            annotation.border = PDFBorder()
            annotation.border?.lineWidth = 0
            page.addAnnotation(annotation)
        }
    }
}
#endif
