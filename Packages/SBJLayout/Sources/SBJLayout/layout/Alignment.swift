import CoreGraphics
import UIKit

public struct Alignment: OptionSet, Sendable, Codable, CustomStringConvertible, CustomDebugStringConvertible {
	public let rawValue: Int
	public init(rawValue: Int) { self.rawValue = rawValue }

	public static let left   = Alignment(rawValue: 1 << 0) //1
	public static let right  = Alignment(rawValue: 1 << 1) //2
	public static let top    = Alignment(rawValue: 1 << 2) //4
	public static let bottom = Alignment(rawValue: 1 << 3) //8

	public static let centerX: Alignment = [.left, .right]
	public static let centerY: Alignment = [.top, .bottom]

	public static let leftTop: Alignment    = [.left, .top]
	public static let leftCenter: Alignment = [.left, .centerY]
	public static let leftBottom: Alignment = [.left, .bottom]

	public static let centerTop: Alignment    = [.centerX, .top]
	public static let center: Alignment       = [.centerX, .centerY]
	public static let centerBottom: Alignment = [.centerX, .bottom]

	public static let rightTop: Alignment    = [.right, .top]
	public static let rightCenter: Alignment = [.right, .centerY]
	public static let rightBottom: Alignment = [.right, .bottom]

	// if empty, assumes leftTop
	public func apply(size: CGSize, in rect: CGRect) -> CGRect {
		let x: CGFloat
		if contains(.centerX) {
			x = rect.minX + (rect.width - size.width) * 0.5
		} else if contains(.right) {
			x = rect.maxX - size.width
		} else if contains(.left) {
			x = rect.minX
		} else {
			x = rect.minX // assume left
		}
		let y: CGFloat
		if contains(.centerY) {
			y = rect.minY + (rect.height - size.height) * 0.5
		} else if contains(.bottom) {
			y = rect.maxY - size.height
		} else if contains(.top) {
			y = rect.minY
		} else {
			y = rect.minY // assume top
		}
		return .init(x: x, y: y, size: size)
	}

	public var description: String {
		if contains(.center) {
			return "Centered"
		}
		let x: String
		if contains(.centerX) {
			x = "Center"
		} else if contains(.right) {
			x = "Right"
		} else if contains(.left) {
			x = "Left"
		} else {
			x = ""
		}
		let y: String
		if contains(.centerY) {
			y = "Center"
		} else if contains(.bottom) {
			y = "Bottom"
		} else if contains(.top) {
			y = "Top"
		} else {
			y = ""
		}
		return "\(x)\(y)"
	}

	public var debugDescription: String {
		"\(description)\(rawValue)"
	}
}

// NSAttributedString has no notion of vertical alignment
public extension Alignment {
	init(_ textAlignment: NSTextAlignment) {
		switch (textAlignment) {
			case .left:  self = .leftTop
			case .right: self = .rightTop
			default:     self = .centerTop
		}
	}

	var textAlignment: NSTextAlignment {
		if contains(.centerX) { return .center }
		if contains(.right)  { return .right }
		return .left
	}
}
