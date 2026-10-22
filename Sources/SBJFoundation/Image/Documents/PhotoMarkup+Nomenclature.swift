import SBJLocalization

extension PhotoMarkup: StringPresentable {
	public var description: String { "Markup in \(coordinateSpace.description), \(canvasSize.description)" }
}
