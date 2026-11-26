import SBJLocalization

extension PhotoColorAdjustments: SBJTextPresentable {
	public var presentedValue: String { isNeutral ? "No color adjustments" : "Color adjustments applied" }
}
