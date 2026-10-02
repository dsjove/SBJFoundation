import Foundation
import UIKit
import SwiftUI

@SBJStructure
public struct CodableFont: SBJFoundationType, Comparable, Hashable, Sendable, CustomDebugStringConvertible {
	public enum Weight: String, SBJFoundationType, CaseIterable, Comparable, Sendable {
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

		var uiWeight: UIFont.Weight {
			switch self {
			case .ultraLight: .ultraLight
			case .thin: .thin
			case .light: .light
			case .regular: .regular
			case .medium: .medium
			case .semibold: .semibold
			case .bold: .bold
			case .heavy: .heavy
			case .black: .black
			}
		}
	}

	public enum Width: String, SBJFoundationType, CaseIterable, Comparable, Sendable {
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
	@SBJPresentation(.fontFamily)
	public var name: String?
	public var size: Double
	public var weight: Weight
	public var italic: Bool
	public var width: Width

	@SBJDesignatedInit
	public init(
		_ name: String? = nil,
		ofSize size: Double = 12.0,
		weight: Weight = .regular,
		italic: Bool = false,
		width: Width = .standard
	) {
		self.name = name
		self.size = size
		self.weight = weight
		self.italic = italic
		self.width = width
	}

	public static func < (lhs: CodableFont, rhs: CodableFont) -> Bool {
		switch (lhs.name, rhs.name) {
		case (nil, nil):
			break
		case (nil, _?):
			return true
		case (_?, nil):
			return false
		case let (lhsName?, rhsName?) where lhsName != rhsName:
			return lhsName.localizedStandardCompare(rhsName) == .orderedAscending
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
		"\(name.map { $0.debugDescription } ?? "System") \(size) \(weight.rawValue) \(width.rawValue)\(italic ? " italic" : "")"
	}

	/// Creates the described font without using a cache.
	///
	/// Rendering paths that repeatedly request the same fonts should use
	/// ``CodableFontCache`` instead.
	public var font: UIFont {
		font(scale: 1.0)
	}

	/// Creates the described font with a multiplier applied to its point size.
	/// This method does not cache the resulting UIFont object.
	public func font(scale: Double) -> UIFont {
		CodableFontCache.shared.uncachedFont(for: self, scale: scale)
	}
}

#if !os(tvOS) && !os(watchOS)
public extension CodableFont {
    @MainActor
    static func sbjEditorFieldIsVisuallyIneffective<Value>(
        _ keyPath: WritableKeyPath<CodableFont, Value>,
        in root: CodableFont
    ) -> Bool {
        let capabilities = CodableFontCache.shared.capabilities(forFamily: root.name)
        let erasedKeyPath = keyPath as AnyKeyPath

        if erasedKeyPath == (\CodableFont.weight as AnyKeyPath) {
            return !capabilities.weightIsEffective
        }
        if erasedKeyPath == (\CodableFont.italic as AnyKeyPath) {
            return !capabilities.italicIsEffective
        }
        if erasedKeyPath == (\CodableFont.width as AnyKeyPath) {
            return !capabilities.widthIsEffective
        }
        return false
    }
}
#endif

