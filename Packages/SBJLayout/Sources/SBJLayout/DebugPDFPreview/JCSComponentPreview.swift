#if DEBUG && os(iOS)
// Source-only SBJLayout integration fixture; no application target is included.
import Foundation
import UIKit

/// Independent integration examples for every current JCS construct. The preview is
/// intentionally separate from the tenant-facing, two-page rental application.
public enum JCSComponentPreview {
    private static let email = URL(string: "mailto:propertiesbyjovellc@gmail.com")!
    private static let website = URL(string: "https://developer.apple.com/documentation/pdfkit")!
    private static let font = UIFont.systemFont(ofSize: 11)

    private struct RuleSample: Renderable {
        func measure(bounds: CGSize) -> CGSize { CGSize(width: 450, height: 24) }
        func minimumMeasure(bounds: CGSize) -> CGSize { measure(bounds: bounds) }
        func render(in allocated: CGRect, measured: CGSize, align: Alignment) {
            let rect = align.apply(size: measured, in: allocated)
            JCSLine(stroke: .darkGray, lineWidth: 1).draw(from: CGPoint(x: rect.minX, y: rect.midY), to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }

    public static func create(logo: UIImage? = nil, showBounds: Bool = false) -> PDFRenderResult {
        // Grid's built-in debug flags are intentionally not modified globally. Rectangular
        // diagnostics are isolated in the preview and do not change annotation geometry.
        let grid = Grid(vertFlow: .init(.fixed(470)), rows: .init(gap: 9)) {
            JCSText(verbatim: "SBJLayout: JCS Diagnostic Preview", font: .boldSystemFont(ofSize: 18))
            JCSText(verbatim: "Text: short, intrinsic, bold, and wrapping samples", font: font)
            JCSText(verbatim: "This longer sentence tests word wrapping when its allocated width is constrained and uses ordinary JCSText behavior.", font: font, lines: 2...3)
            JCSText(verbatim: "Bold / centered", font: .boldSystemFont(ofSize: 13), align: .center)
            Panel(background: JCSRect(fill: .lightGray, stroke: .black, lineWidth: 0.5, radius: 4)) {
                JCSText(verbatim: "Panel: fill, stroke, radius", font: font)
            }
            RuleSample()
            JCSText(verbatim: "JCSImage: logo (aspect fit)", font: font)
            // Keep the source image intrinsic; no placeholder artwork is manufactured.
            JCSImage(logo, aspect: .fit, cornerRadius: 2)
            JCSLink(email, content: JCSText(verbatim: "JCSLink: email", font: font))
            JCSLink(website, content: JCSText(verbatim: "JCSLink: website", font: font))
            JCSTextField(name: "preview.text.empty", minChars: 36)
            JCSTextField(name: "preview.text.value", value: "Editable text", minChars: 36)
            JCSTextField(name: "preview.text.multiline", value: "First line", multiline: true, minChars: 36, height: 56)
            JCSTextField(name: "preview.text.readonly", value: "Read only", minChars: 36, traits: .init(readOnly: true))
            JCSTextField(name: "preview.text.maximum", minChars: 36, traits: .init(maximumLength: 12))
            JCSText(verbatim: "Checkbox: off / on", font: font)
            Grid(table: [.init(.fixed(45)), .init(.fixed(45))], rows: .init(gap: 0)) {
                JCSCheckbox(name: "preview.checkbox.off")
                JCSCheckbox(name: "preview.checkbox.on", checked: true)
            }
            JCSText(verbatim: "Radio: one selection within a named group", font: font)
            JCSRadioGroup(name: "preview.radio.first", options: [
                .init("One", value: "one"), .init("Two", value: "two"), .init("Three", value: "three")
            ], selected: "two")
            JCSRadioGroup(name: "preview.radio.second", options: [
                .init("Yes", value: "yes"), .init("No", value: "no")
            ])
            JCSText(verbatim: "Nested Grid and Panel", font: font)
            Grid(table: [.init(.fixed(215)), .init(.fixed(215))], rows: .init(gap: 0)) {
                Panel(background: JCSRect(fill: .white, stroke: .gray, lineWidth: 1)) {
                    JCSText(verbatim: "left cell", font: font)
                }
                Panel(background: JCSRect(fill: .white, stroke: .gray, lineWidth: 1)) {
                    JCSText(verbatim: "right cell", font: font)
                }
            }
            JCSPageNumber(font: font)
            if showBounds {
                Panel(background: JCSRect(fill: .clear, stroke: .red, lineWidth: 0.6)) {
                    JCSText(verbatim: "Debug: red rectangle marks this panel's layout bounds", font: font)
                }
            }
        }
        return PDFGenerator(title: "SBJLayout JCS Diagnostic Preview", creator: "SBJLayout").form(grid)
    }
}

#endif
