#if !os(watchOS)
import CoreGraphics
import UIKit

/// A graphical renderable which becomes an editable PDF AcroForm text field when exported.
public struct JCSTextField: Renderable {
    public let name: String
    public let value: String
    public let multiline: Bool
    public let font: UIFont
    public let color: UIColor
    public let border: UIColor
    public let height: CGFloat
    public let minChars: Int
    public let traits: JCSFormTraits

    public init(name: String, value: String = "", multiline: Bool = false,
                font: UIFont = .systemFont(ofSize: 11), color: UIColor = .black,
                border: UIColor = .lightGray, minChars: Int = 20,
                height: CGFloat = 24, traits: JCSFormTraits = .init()) {
        self.name = name; self.value = value; self.multiline = multiline
        self.font = font; self.color = color; self.border = border
        self.minChars = minChars; self.height = height; self.traits = traits
    }

    public func measure(bounds: CGSize) -> CGSize {
        let intrinsic = ceil(CGFloat(minChars) * font.pointSize * 0.58) + 12
        return CGSize(width: bounds.width.isUnbounded ? intrinsic : min(bounds.width, intrinsic),
                      height: height)
    }
    public func minimumMeasure(bounds: CGSize) -> CGSize { measure(bounds: bounds) }

    public func render(in allocated: CGRect, measured: CGSize, align: Alignment) {
        let rect = align.apply(size: measured, in: allocated)
        JCSRect(fill: .white, stroke: border, lineWidth: 0.7, radius: 2).draw(in: rect)
        let textRect = rect.insetBy(dx: 5, dy: 3)
        if PDFFormEnvironment.collector == nil {
            (value as NSString).draw(in: textRect, withAttributes: [.font: font, .foregroundColor: color])
        }
        PDFFormEnvironment.collector?.add(name, bounds: rect,
            kind: .text(value, multiline: multiline, font: font, color: color, alignment: .left), traits: traits)
    }
}

/// Independent AcroForm checkbox with a graphical fallback for non-PDF rendering.
public struct JCSCheckbox: Renderable {
    public let name: String
    public let checked: Bool
    public let side: CGFloat
    public let traits: JCSFormTraits
    public init(name: String, checked: Bool = false, side: CGFloat = 13, traits: JCSFormTraits = .init()) {
        self.name = name; self.checked = checked; self.side = side; self.traits = traits
    }
    public func measure(bounds: CGSize) -> CGSize { CGSize(width: side, height: side) }
    public func minimumMeasure(bounds: CGSize) -> CGSize { measure(bounds: bounds) }
    public func render(in allocated: CGRect, measured: CGSize, align: Alignment) {
        let rect = align.apply(size: measured, in: allocated)
        JCSRect(fill: .white, stroke: .darkGray, lineWidth: 0.8).draw(in: rect)
        if checked && PDFFormEnvironment.collector == nil {
            let mark = UIBezierPath()
            mark.move(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.midY))
            mark.addLine(to: CGPoint(x: rect.midX - 1, y: rect.maxY - rect.height * 0.2))
            mark.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.15, y: rect.minY + rect.height * 0.2))
            UIColor.black.setStroke(); mark.lineWidth = 1.6; mark.stroke()
        }
        PDFFormEnvironment.collector?.add(name, bounds: rect, kind: .checkbox(checked), traits: traits)
    }
}

/// A single logical value, represented as mutually exclusive PDF radio widgets.
public struct JCSRadioGroup: Renderable {
    public struct Option {
        public let label: String
        public let value: String
        public init(_ label: String, value: String) { self.label = label; self.value = value }
    }
    public let name: String
    public let options: [Option]
    public let selected: String?
    public let side: CGFloat
    public let spacing: CGFloat
    public let font: UIFont
    public let traits: JCSFormTraits

    public init(name: String, options: [Option], selected: String? = nil,
                side: CGFloat = 13, spacing: CGFloat = 12,
                font: UIFont = .systemFont(ofSize: 10), traits: JCSFormTraits = .init()) {
        self.name = name; self.options = options; self.selected = selected
        self.side = side; self.spacing = spacing; self.font = font; self.traits = traits
    }
    private func itemWidth(_ option: Option) -> CGFloat {
        ceil((option.label as NSString).size(withAttributes: [.font: font]).width) + side + 5
    }
    public func measure(bounds: CGSize) -> CGSize {
        CGSize(width: options.reduce(CGFloat.zero) { $0 + itemWidth($1) } + CGFloat(max(0, options.count - 1)) * spacing,
               height: max(side, ceil(font.lineHeight)))
    }
    public func minimumMeasure(bounds: CGSize) -> CGSize { measure(bounds: bounds) }
    public func render(in allocated: CGRect, measured: CGSize, align: Alignment) {
        let origin = align.apply(size: measured, in: allocated).origin
        var x = origin.x
        for option in options {
            let circle = CGRect(x: x, y: origin.y + (measured.height - side)/2, width: side, height: side)
            let path = UIBezierPath(ovalIn: circle)
            UIColor.white.setFill(); path.fill(); UIColor.darkGray.setStroke(); path.lineWidth = 0.8; path.stroke()
            if option.value == selected && PDFFormEnvironment.collector == nil {
                UIColor.black.setFill(); UIBezierPath(ovalIn: circle.insetBy(dx: 3, dy: 3)).fill()
            }
            let labelRect = CGRect(x: x + side + 5, y: origin.y, width: itemWidth(option) - side - 5, height: measured.height)
            (option.label as NSString).draw(in: labelRect, withAttributes: [.font: font, .foregroundColor: UIColor.black])
            PDFFormEnvironment.collector?.add(name, bounds: circle,
                kind: .radio(value: option.value, selected: option.value == selected), traits: traits)
            x += itemWidth(option) + spacing
        }
    }
}
#endif
