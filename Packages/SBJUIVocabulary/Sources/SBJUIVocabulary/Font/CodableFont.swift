import Foundation
import SBJDataDefinition

@SBJStructure
public struct CodableFont: Codable, Equatable, Comparable, Hashable, Sendable, CustomDebugStringConvertible {
	public enum Weight: String, Codable, Equatable, CaseIterable, Comparable, Sendable {
		case ultraLight
		case thin
		case light
		case regular
		case medium
		case semibold
		case bold
		case heavy
		case black

		public static func < (lhs: Self, rhs: Self) -> Bool {
			lhs.order < rhs.order
		}

		fileprivate var order: Int {
			switch self {
			case .ultraLight: 0
			case .thin: 1
			case .light: 2
			case .regular: 3
			case .medium: 4
			case .semibold: 5
			case .bold: 6
			case .heavy: 7
			case .black: 8
			}
		}
	}

	public enum Width: String, Codable, Equatable, CaseIterable, Comparable, Sendable {
		case condensed
		case standard
		case expanded

		public static func < (lhs: Self, rhs: Self) -> Bool {
			lhs.order < rhs.order
		}

		fileprivate var order: Int {
			switch self {
			case .condensed: 0
			case .standard: 1
			case .expanded: 2
			}
		}
	}

	/// Font family name. `nil` means the system font.
	public var family: FontFamily?
	public var size: Double
	public var weight: Weight
	public var italic: Bool
	public var width: Width

	@SBJDesignatedInit
	public init(
		_ name: FontFamily? = nil,
		ofSize size: Double = 12.0,
		weight: Weight = .regular,
		italic: Bool = false,
		width: Width = .standard
	) {
		self.family = name
		self.size = size
		self.weight = weight
		self.italic = italic
		self.width = width
	}

	public static func < (lhs: CodableFont, rhs: CodableFont) -> Bool {
		switch (lhs.family, rhs.family) {
		case (nil, nil):
			break
		case (nil, _?):
			return true
		case (_?, nil):
			return false
		case let (lhsName?, rhsName?) where lhsName != rhsName:
			return lhsName.name.localizedStandardCompare(rhsName.name) == .orderedAscending
		default:
			break
		}

		if lhs.size != rhs.size { return lhs.size < rhs.size }
		if lhs.weight != rhs.weight { return lhs.weight < rhs.weight }
		if lhs.italic != rhs.italic { return !lhs.italic }
		if lhs.width != rhs.width { return lhs.width < rhs.width }
		return false
	}

	public var debugDescription: String {
		"\(family.map { $0.debugDescription } ?? "System") \(size) \(weight.rawValue) \(width.rawValue)\(italic ? " italic" : "")"
	}
}

