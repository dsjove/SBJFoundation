import SBJLocalization

extension PhotoMarkupCanvasSize: SBJTextPresentable {
	public var presentedValue: String { "\(width) × \(height)" }
}
