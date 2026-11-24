import SBJLocalization
import SBJStructure

@SBJStructureExtension
extension PhotoMirrorState: SBJTextPresentable {
	public var presentedValue: String { horizontal && vertical ? "Mirrored horizontally and vertically" : horizontal ? "Mirrored horizontally" : vertical ? "Mirrored vertically" : "Not mirrored" }
	public static let horizontalNomenclature = #SBJAutoNomenclature(summary: "Whether the image is mirrored left-to-right.",
		details: "False preserves the source orientation; true reflects the image across its vertical axis.",
		accessibilityLabel: "Mirror Horizontally",
		accessibilityHint: "Reflects the image from left to right."
	)
	public static let verticalNomenclature = #SBJAutoNomenclature(summary: "Whether the image is mirrored top-to-bottom.",
		details: "False preserves the source orientation; true reflects the image across its horizontal axis.",
		accessibilityLabel: "Mirror Vertically",
		accessibilityHint: "Reflects the image from top to bottom."
	)
}
