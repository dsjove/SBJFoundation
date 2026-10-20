import Foundation
import SBJDataDefinition
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

extension CodableColor {
	public init(color: Color.Resolved) {
		self.init(
			Double(color.red),
			Double(color.green),
			Double(color.blue),
			Double(color.opacity)
		)
	}

	public var swiftUIColor: Color {
		get {
			Color(red: red, green: green, blue: blue, opacity: opacity)
		}
		set {
			self = .init(color: newValue)
		}
	}
}

#if canImport(UIKit)
public extension CodableColor {
	init(color: UIColor) {
		var red: CGFloat = 0
		var green: CGFloat = 0
		var blue: CGFloat = 0
		var alpha: CGFloat = 0
		if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
			self.init(Double(red), Double(green), Double(blue), Double(alpha))
		} else {
			self.init(0, 0, 0, 1)
		}
	}

	var uiColor: UIColor {
		UIColor(
			red: CGFloat(red),
			green: CGFloat(green),
			blue: CGFloat(blue),
			alpha: CGFloat(opacity)
		)
	}
}
#endif
