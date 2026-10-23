import SBJDataDefinition
import SBJLocalization

@SBJPropertyInfo
extension PhotoRotation: StringPresentable {
	public var description: String { "Rotation \(degrees)°" }
	public static let quarterTurnsInfo = SBJPropertyInfo(
		summary: "Number of 90-degree clockwise rotations, normalized to zero through three.",
		details: "Quarter-turn controls may rotate in either direction; the stored representation remains normalized modulo four.",
		accessibilityLabel: "Quarter Turn Rotation",
		accessibilityHint: "Rotates the image by 90 degrees."
	)
	public static let fineDegreesInfo = SBJPropertyInfo(
		title: "Straighten",
		summary: "Fine rotation used by the straighten control.",
		details: "The editor constrains interactive straightening to -15 through 15 degrees.",
		accessibilityLabel: "Straighten",
		accessibilityHint: "Adjust the image rotation in small increments."
	)
}
