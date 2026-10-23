import SBJLocalization

extension PhotoFramingConstraint: StringPresentable {
	public var description: String { self == .cover ? "Image covers the frame" : self == .overlap ? "Image overlaps the frame" : "Unconstrained image framing" }
}
