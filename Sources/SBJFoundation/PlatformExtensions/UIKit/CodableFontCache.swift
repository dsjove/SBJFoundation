import Foundation
import UIKit

/// A process-wide cache for installed font metadata and realized `UIFont` objects.
///
/// The cache is synchronous and actor-neutral. Installed font families/faces are
/// enumerated once and retained for the process lifetime. Realized fonts are also
/// retained indefinitely for now.
public final class CodableFontCache: @unchecked Sendable {
	public struct FamilyCapabilities: Sendable {
		/// `true` when choosing a different requested weight can select a different face.
		public let weightIsEffective: Bool
		/// `true` when the family contains both upright and italic faces.
		public let italicIsEffective: Bool
		/// `true` when choosing a different requested width can select a different face.
		public let widthIsEffective: Bool
	}

	public static let shared: CodableFontCache = {
		let cache = CodableFontCache()
		cache.preflightInBackground()
		return cache
	}()

	private struct Key: Hashable {
		let font: CodableFont
		let scale: Double
	}

	private struct Face: Sendable {
		let postScriptName: String
		let weight: CGFloat
		let italic: Bool
		let width: CodableFont.Width
	}

	private struct Catalog: Sendable {
		let families: [String]
		let facesByFamily: [String: [Face]]
	}

	private let fontLock = NSLock()
	private var fonts: [Key: UIFont] = [:]

	private let catalogLock = NSLock()
	private var cachedCatalog: Catalog?

	public init() {}

	/// Starts installed-font enumeration without blocking the caller. The shared
	/// cache invokes this immediately on first access, so applications that render
	/// with the cache before presenting an editor normally have a warm font menu.
	public func preflightInBackground() {
		DispatchQueue.global(qos: .utility).async { [self] in
			preflight()
		}
	}

	/// Forces installed-font enumeration and metadata caching now.
	/// Safe to call repeatedly and from any actor/thread.
	public func preflight() {
		_ = catalog()
	}

	/// Installed font *families*, not individual faces/variations.
	/// `System` is intentionally not included; editors represent it with nil.
	public var availableFontFamilies: [String] {
		catalog().families
	}

	/// Describes which variation controls can have an effect for a font family.
	///
	/// This is presentation metadata only. A caller should keep the requested
	/// weight, italic, and width values even when the selected family does not
	/// currently provide a meaningful variation on that axis.
	public func capabilities(forFamily family: String?) -> FamilyCapabilities {
		guard let family else {
			// The system font supports all three requested variation axes.
			return FamilyCapabilities(
				weightIsEffective: true,
				italicIsEffective: true,
				widthIsEffective: true
			)
		}

		guard let faces = catalog().facesByFamily[family], !faces.isEmpty else {
			// Be conservative for an unknown/stale family name: do not make a
			// perfectly valid requested attribute look unavailable.
			return FamilyCapabilities(
				weightIsEffective: true,
				italicIsEffective: true,
				widthIsEffective: true
			)
		}

		// Do not infer editor capability from the metadata attached to the named
		// faces. Some installed families (Arial is a common example) expose real
		// bold/italic faces while reporting incomplete or identical descriptor-trait
		// metadata for those faces. What matters to the editor is whether the same
		// UIFontDescriptor matching path used by `makeFont` actually resolves a
		// different face when an attribute is requested.
		let base = UIFontDescriptor(fontAttributes: [.family: family])

		func matchedFontName(_ traits: [UIFontDescriptor.TraitKey: Any]) -> String {
			let descriptor = traits.isEmpty
				? base
				: base.addingAttributes([.traits: traits])
			return UIFont(descriptor: descriptor, size: 12).fontName
		}

		let weightNames = Set([
			matchedFontName([.weight: UIFont.Weight.ultraLight.rawValue]),
			matchedFontName([.weight: UIFont.Weight.regular.rawValue]),
			matchedFontName([.weight: UIFont.Weight.black.rawValue])
		])

		let italicNames = Set([
			matchedFontName([:]),
			matchedFontName([.slant: 0.2])
		])

		let widthNames = Set([
			matchedFontName([.width: -0.5]),
			matchedFontName([:]),
			matchedFontName([.width: 0.5])
		])

		return FamilyCapabilities(
			weightIsEffective: weightNames.count > 1,
			italicIsEffective: italicNames.count > 1,
			widthIsEffective: widthNames.count > 1
		)
	}

	/// Returns a cached `UIFont` for the supplied description and scale.
	/// A font is created only the first time a particular pair is requested.
	public func font(for font: CodableFont, scale: Double = 1.0) -> UIFont {
		let key = Key(font: font, scale: scale)

		if let cached = fontLock.sbjWithLock({ fonts[key] }) {
			return cached
		}

		let realized = makeFont(for: font, scale: scale)

		return fontLock.sbjWithLock {
			if let cached = fonts[key] {
				return cached
			}
			fonts[key] = realized
			return realized
		}
	}

	/// Realizes a font using preflighted family metadata when needed but does not
	/// retain the resulting UIFont in the realized-font cache.
	public func uncachedFont(for font: CodableFont, scale: Double = 1.0) -> UIFont {
		makeFont(for: font, scale: scale)
	}

	private func makeFont(for font: CodableFont, scale: Double) -> UIFont {
		let size = CGFloat(font.size * scale)

		// System fonts have a direct weight API. Only add descriptor traits for
		// variations that actually need them; in particular, `.standard` width
		// means "no width override" rather than forcing a descriptor rematch.
		guard let family = font.name else {
			let base = UIFont.systemFont(ofSize: size, weight: font.weight.uiWeight)
			let descriptor = descriptorApplyingVariations(
				to: base.fontDescriptor,
				font: font,
				includeWeight: false
			)
			return UIFont(descriptor: descriptor, size: size)
		}

		// The editor stores family names. Let UIFontDescriptor choose the best
		// matching face from that family using the requested weight and optional
		// variations instead of selecting a concrete PostScript face ourselves.
		var descriptor = UIFontDescriptor(fontAttributes: [.family: family])
		descriptor = descriptorApplyingVariations(
			to: descriptor,
			font: font,
			includeWeight: true
		)
		let matched = UIFont(descriptor: descriptor, size: size)

		// A caller may still supply a PostScript face name directly. Family-name
		// descriptors normally resolve correctly; retain this fallback for source
		// compatibility with older callers.
		if matched.familyName.caseInsensitiveCompare(family) == .orderedSame
			|| matched.fontName.caseInsensitiveCompare(family) == .orderedSame {
			return matched
		}
		if let direct = UIFont(name: family, size: size) {
			let directDescriptor = descriptorApplyingVariations(
				to: direct.fontDescriptor,
				font: font,
				includeWeight: true
			)
			return UIFont(descriptor: directDescriptor, size: size)
		}
		return matched
	}

	private func descriptorApplyingVariations(
		to descriptor: UIFontDescriptor,
		font: CodableFont,
		includeWeight: Bool
	) -> UIFontDescriptor {
		var traits: [UIFontDescriptor.TraitKey: Any] = [:]

		if includeWeight {
			traits[.weight] = font.weight.uiWeight.rawValue
		}

		// Do not write a width trait for `.standard`. A zero/standard width trait
		// can force UIKit to rematch the descriptor and lose the selected weight.
		switch font.width {
		case .condensed:
			traits[.width] = -0.5
		case .standard:
			break
		case .expanded:
			traits[.width] = 0.5
		}

		if font.italic {
			traits[.slant] = 0.2
		}

		guard !traits.isEmpty else { return descriptor }
		return descriptor.addingAttributes([.traits: traits])
	}

	private func catalog() -> Catalog {
		catalogLock.sbjWithLock {
			if let cachedCatalog {
				return cachedCatalog
			}
			let built = Self.buildCatalog()
			cachedCatalog = built
			return built
		}
	}

	private static func buildCatalog() -> Catalog {
		let families = UIFont.familyNames.sorted {
			$0.localizedStandardCompare($1) == .orderedAscending
		}

		var facesByFamily: [String: [Face]] = [:]
		facesByFamily.reserveCapacity(families.count)

		for family in families {
			facesByFamily[family] = UIFont.fontNames(forFamilyName: family).compactMap { name in
				guard let font = UIFont(name: name, size: 12) else { return nil }
				let descriptor = font.fontDescriptor
				let symbolicTraits = descriptor.symbolicTraits
				let attributes = descriptor.fontAttributes[.traits] as? [UIFontDescriptor.TraitKey: Any]
				let weight = (attributes?[.weight] as? NSNumber)?.doubleValue ?? 0
				let widthValue = (attributes?[.width] as? NSNumber)?.doubleValue ?? 0

				let width: CodableFont.Width
				if symbolicTraits.contains(.traitCondensed) || widthValue < -0.1 {
					width = .condensed
				} else if symbolicTraits.contains(.traitExpanded) || widthValue > 0.1 {
					width = .expanded
				} else {
					width = .standard
				}

				return Face(
					postScriptName: name,
					weight: CGFloat(weight),
					italic: symbolicTraits.contains(.traitItalic),
					width: width
				)
			}
		}

		return Catalog(families: families, facesByFamily: facesByFamily)
	}
}

private extension NSLock {
	func sbjWithLock<T>(_ body: () throws -> T) rethrows -> T {
		lock()
		defer { unlock() }
		return try body()
	}
}
