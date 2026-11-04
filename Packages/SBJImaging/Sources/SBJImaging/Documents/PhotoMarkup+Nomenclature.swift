import SBJLocalization

extension PhotoMarkup: SBJTextPresentable {
	public var presentedValue: String { "Markup in \(coordinateSpace.presentedValue), \(canvasSize.presentedValue)" }
}
