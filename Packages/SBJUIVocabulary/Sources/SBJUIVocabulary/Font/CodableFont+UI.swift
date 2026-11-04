import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import SBJDataDefinition

extension CodableFont {
	/// Creates the described font without using a cache.
	///
	/// Rendering paths that repeatedly request the same fonts should use
	/// ``CodableFontCache`` instead.
	public var font: SBJFont {
		font(scale: 1.0)
	}

	/// Creates the described font with a multiplier applied to its point size.
	/// This method does not cache the resulting SBJFont object.
	public func font(scale: Double) -> SBJFont {
		CodableFontCache.shared.uncachedFont(for: self, scale: scale)
	}
}

extension CodableFont.Weight {
	var nativeWeight: SBJFont.Weight {
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

#if !os(tvOS) && !os(watchOS)
public extension CodableFont {
    @MainActor
    static func sbjEditorFieldIsVisuallyIneffective<Value>(
        _ keyPath: WritableKeyPath<CodableFont, Value>,
        in root: CodableFont
    ) -> Bool {
        let capabilities = CodableFontCache.shared.capabilities(forFamily: root.family)
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
