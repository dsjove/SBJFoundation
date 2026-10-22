import SBJLocalization

extension PhotoSkew: StringPresentable {
	public var description: String { "Horizontal skew \(horizontalDegrees)°, vertical skew \(verticalDegrees)°" }
}
