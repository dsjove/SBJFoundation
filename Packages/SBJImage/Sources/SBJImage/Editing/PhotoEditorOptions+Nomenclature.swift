import SBJDataDefinition
import SBJLocalization

@SBJPropertyInfo
extension PhotoEditorOptions: SBJTextPresentable {
	public var presentedValue: String { "\(cropOptions.count) crop options, maximum zoom \(maximumMagnification)" }
	public static let cropOptionsInfo = SBJPropertyInfo(
		summary: "Crop modes offered by the photo editor.",
		details: "Include None when uncropped editing is allowed. The order is the order presented in the crop menu."
	)
	public static let initialCropInfo = SBJPropertyInfo(
		summary: "Preferred starting crop when more than one crop mode is available.",
		details: "Ignored when cropOptions is empty or contains one option. With multiple options, if this crop is not present, the first configured crop option is used."
	)
	public static let allowsQuarterTurnRotationInfo = SBJPropertyInfo(
		title: "Quarter-Turn Rotation",
		summary: "Whether 90-degree rotation controls are available.",
		details: "When enabled, the editor exposes quarter-turn rotation and can omit a redundant vertical mirror control."
	)
	public static let allowsFreeRotationInfo = SBJPropertyInfo(
		title: "Straightening",
		summary: "Whether fine rotation is available for straightening an image.",
		details: "Fine rotation uses the straighten control and is constrained by the PhotoRotation model."
	)
	public static let allowsMirrorInfo = SBJPropertyInfo(
		title: "Mirroring",
		summary: "Whether image mirror controls are available.",
		details: "The available axes also depend on whether quarter-turn rotation is enabled."
	)
	public static let framingConstraintInfo = SBJPropertyInfo(
		summary: "Controls how an uncropped image may move relative to the editor frame.",
		details: "Active crops always use cover framing so the crop rectangle cannot expose empty pixels."
	)
	public static let maximumMagnificationInfo = SBJPropertyInfo(
		summary: "Largest user zoom relative to the minimum legal image scale.",
		details: "Values below 1 are normalized to 1 by the initializer."
	)
	public static let renderCropGhostInfo = SBJPropertyInfo(
		title: "Crop Ghost Opacity",
		summary: "Opacity of the uncropped image shown behind the active crop.",
		details: "Values less than or equal to zero disable the ghost. Values above 1 render as fully opaque."
	)
	public static let allowsNoneFramingInfo = SBJPropertyInfo(
		title: "Allows Unconstrained Framing",
		summary: "Permits the .none framing policy to leave image placement unconstrained.",
		details: "This affects uncropped editing; crop modes still require the image to cover the crop frame."
	)
	public static let allowsMarkupInfo = SBJPropertyInfo(
		title: "Markup",
		summary: "Whether drawing and markup tools are available.",
		details: "Markup is rendered into the completed image when present."
	)
	public static let allowsShareInfo = SBJPropertyInfo(
		title: "Sharing",
		summary: "Whether the editor exposes sharing for the current edited image.",
		details: "Sharing renders the current edit state without completing the editor."
	)
}
