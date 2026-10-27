import Foundation

public struct CodableColor: Codable, Equatable, Comparable, CustomDebugStringConvertible {
	public var red: Double
	public var green: Double
	public var blue: Double
	public var opacity: Double

	public init(_ red: Double, _ green: Double, _ blue: Double, _ opacity: Double = 1.0) {
		self.red = red
		self.green = green
		self.blue = blue
		self.opacity = opacity
	}

	public init() {
		self.red = 1.0
		self.green = 1.0
		self.blue = 1.0
		self.opacity = 1.0
	}

	public static func < (lhs: CodableColor, rhs: CodableColor) -> Bool {
		if lhs.red != rhs.red { return lhs.red < rhs.red }
		if lhs.green != rhs.green { return lhs.green < rhs.green }
		if lhs.blue != rhs.blue { return lhs.blue < rhs.blue }
		return lhs.opacity < rhs.opacity
	}

	public var debugDescription: String {
		"(\(red), \(green), \(blue), \(opacity))"
	}

	/// Perceived luminance approximation used for contrast decisions without
	/// requiring a platform color type.
	public var brightness: Double {
		(red * 299 + green * 587 + blue * 114) / 1000
	}

	public var isLight: Bool {
		brightness > 0.5
	}
}
