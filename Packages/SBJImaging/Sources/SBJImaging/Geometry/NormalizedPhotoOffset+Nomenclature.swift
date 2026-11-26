import SBJLocalization
import SBJStructure

@SBJStructureExtension
extension NormalizedPhotoOffset: SBJTextPresentable {
	@SBJExclude
	public var presentedValue: String { "Horizontal offset \(x), vertical offset \(y)" }
	public static let xNomenclature = SBJNomenclature(
		title: "Horizontal Placement",
		summary: "Horizontal image placement normalized to the rendered image width.",
		details: "A value of 0 is centered; positive values move right and negative values move left.",
		accessibilityLabel: "Horizontal Image Placement",
		accessibilityHint: "Drag the image left or right within the crop."
	)
	public static let yNomenclature = SBJNomenclature(
		title: "Vertical Placement",
		summary: "Vertical image placement normalized to the rendered image height.",
		details: "A value of 0 is centered; positive values move down and negative values move up.",
		accessibilityLabel: "Vertical Image Placement",
		accessibilityHint: "Drag the image up or down within the crop."
	)
}
