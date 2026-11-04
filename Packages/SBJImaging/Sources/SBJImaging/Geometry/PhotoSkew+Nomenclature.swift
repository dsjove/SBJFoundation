import SBJLocalization

extension PhotoSkew: SBJTextPresentable {
	public var presentedValue: String { "Horizontal skew \(horizontalDegrees)°, vertical skew \(verticalDegrees)°" }
}
