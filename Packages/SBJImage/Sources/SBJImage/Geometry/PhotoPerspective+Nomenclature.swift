import SBJLocalization

extension PhotoPerspective: SBJTextPresentable {
	public var presentedValue: String { isIdentity ? "No perspective correction" : "Four-corner perspective correction" }
}
