import SBJLocalization

extension PhotoFramingConstraint: SBJTextPresentable {
	public var presentedValue: String { self == .cover ? "Image covers the frame" : self == .overlap ? "Image overlaps the frame" : "Unconstrained image framing" }
}
