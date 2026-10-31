import SBJLocalization
import SBJDataDefinition

@SBJPropertyInfo
extension PhotoCropState: SBJTextPresentable {
	public var presentedValue: String { "\(option.title) crop, aspect ratio \(freeAspectRatio)" }
	public static let optionInfo = SBJPropertyInfo(
		title: "Crop",
		summary: "Active crop mode.",
		details: "None represents uncropped editing; ratio crops may transpose width and height using swapsDimensions.",
		accessibilityLabel: "Crop",
		accessibilityHint: "Choose the shape and aspect ratio of the visible image."
	)
	public static let freeAspectRatioInfo = SBJPropertyInfo(
		title: "Free Crop Aspect Ratio",
		summary: "Current width-to-height ratio of the resizable free crop.",
		details: "The editor constrains interactive free crop ratios to 0.25 through 4.",
		accessibilityLabel: "Resize Free Crop",
		accessibilityHint: "Drag to change the width and height of the free crop."
	)
	public static let swapsDimensionsInfo = SBJPropertyInfo(
		title: "Swap Width and Height",
		summary: "Transposes width and height for Original and dimensional ratio crops.",
		details: "This has no geometric effect for None, Square, or Free crop modes.",
		accessibilityLabel: "Swap Width and Height",
		accessibilityHint: "Transposes the width and height of the current crop when supported."
	)
}
