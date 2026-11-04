import Foundation
import SwiftUI
import SBJDataDefinition

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
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

#if canImport(AppKit)
public extension CodableColor {
    init(color: NSColor) {
        guard let rgb = color.usingColorSpace(.deviceRGB) else {
            self.init(0, 0, 0, 1)
            return
        }
        self.init(Double(rgb.redComponent), Double(rgb.greenComponent), Double(rgb.blueComponent), Double(rgb.alphaComponent))
    }

    var nsColor: NSColor {
        NSColor(deviceRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(opacity))
    }
}
#endif

// Shared platform-native representation for drawing clients.
public extension CodableColor {
    var sbjColor: SBJColor {
        #if canImport(UIKit)
        uiColor
        #elseif canImport(AppKit)
        nsColor
        #endif
    }
}
