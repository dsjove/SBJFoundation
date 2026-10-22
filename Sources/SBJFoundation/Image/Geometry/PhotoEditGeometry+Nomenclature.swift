import SBJDataDefinition
import SBJLocalization

@SBJPropertyInfo
extension PhotoEditGeometry: StringPresentable {
	public var description: String { "\(crop.description), zoom \(magnification), \(rotation.description)" }
	public static let cropInfo = SBJPropertyInfo(
		summary: "Crop selection and crop-specific geometry.",
		details: "Contains the selected crop mode, free-crop aspect ratio, and width/height transpose state."
	)
	public static let placementInfo = SBJPropertyInfo(
		summary: "Normalized pan position of the image within the edit frame.",
		details: "Placement is stored relative to rendered image dimensions so it remains independent of screen point size.",
		accessibilityLabel: "Image Position",
		accessibilityHint: "Drag to reposition the image inside the crop."
	)
	public static let magnificationInfo = SBJPropertyInfo(
		summary: "User zoom relative to the minimum scale required by the current framing policy.",
		details: "A value of 1 is the minimum legal scale before user zoom is applied.",
		accessibilityLabel: "Image Magnification",
		accessibilityHint: "Pinch to zoom the image inside the crop."
	)
	public static let rotationInfo = SBJPropertyInfo(
		summary: "Quarter-turn and straighten rotation state.",
		details: "Quarter turns and fine straightening are combined when resolving the final image transform."
	)
	public static let mirrorInfo = SBJPropertyInfo(
		summary: "Horizontal and vertical mirror state.",
		details: "Mirror axes are stored independently even when the editor UI exposes only the non-redundant axis."
	)
	public static let perspectiveInfo = SBJPropertyInfo(
		summary: "Reserved perspective correction state.",
		details: "Serialized for document interchange; non-identity perspective rendering is not implemented yet."
	)
	public static let skewInfo = SBJPropertyInfo(
		summary: "Reserved horizontal and vertical skew state.",
		details: "Serialized for document interchange; non-identity skew rendering is not implemented yet."
	)
}
