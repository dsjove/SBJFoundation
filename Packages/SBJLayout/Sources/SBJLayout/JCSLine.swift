import CoreGraphics
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import SBJUIVocabulary

//TODO: API - this is more of a drawing trait than an entity and not a rectangle
public struct JCSLine {
	public let stroke: SBJColor
	public let lineWidth: CGFloat

	public init(stroke: SBJColor, lineWidth: CGFloat) {
		self.stroke = stroke
		self.lineWidth = lineWidth
	}

	public init(stroke: CodableColor, lineWidth: CGFloat) {
		self.init(stroke: stroke.sbjColor, lineWidth: lineWidth)
	}

	@discardableResult
	public func draw(from: CGPoint, to: CGPoint) -> CGRect {
		stroke.setStroke()
		let path = SBJBezierPath()
		path.move(to: from)
		path.addLine(to: to)
		path.lineWidth = lineWidth
		path.stroke()
		return CGRect(x: min(from.x, to.x), y: min(from.y, to.y), width: abs(from.x - to.x), height: abs(from.y - to.y))
	}
}

