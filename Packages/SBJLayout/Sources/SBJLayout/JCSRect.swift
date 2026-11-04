import CoreGraphics
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import SBJUIVocabulary

public struct JCSRect: Chrome {
	public let fill: SBJColor
	public let stroke: SBJColor
	public let lineWidth: CGFloat
	public let radius: CGFloat

	public init(
		fill: SBJColor = .clear,
		stroke: SBJColor = .clear,
		lineWidth: CGFloat = 1.0,
		radius: CGFloat = 0.0
	) {
		self.fill = fill
		self.stroke = stroke
		self.lineWidth = lineWidth
		self.radius = radius
	}

	/// Resolves serializable theme colors at the drawing boundary.
	public init(fill: CodableColor, stroke: CodableColor, lineWidth: CGFloat = 1, radius: CGFloat = 0) {
		self.init(fill: fill.sbjColor, stroke: stroke.sbjColor, lineWidth: lineWidth, radius: radius)
	}

	public func render(in allocated: CGRect, measured: CGSize, align: Alignment) {
		draw(in: allocated)
	}

	@discardableResult
	public func draw(in rect: CGRect) -> CGRect {
		fill.setFill()
		stroke.setStroke()
		let path = SBJBezierPath(borderRect: rect, cornerRadius: radius)
		path.lineWidth = lineWidth
		path.fill()
		path.stroke()
		return rect
	}

	@discardableResult
	public func draw(center: CGPoint) -> CGRect {
		fill.setFill()
		stroke.setStroke()
		let rect = CGRect(
				x: center.x - radius,
				y: center.y - radius,
				width: radius * 2,
				height: radius * 2
			)
		let path = SBJBezierPath(ovalIn: rect)
		path.fill()
		path.stroke()
		return rect
	}
}

