import SBJLocalization

extension PhotoPerspective: StringPresentable {
	public var description: String { isIdentity ? "No perspective correction" : "Four-corner perspective correction" }
}
