import Foundation

@SBJStructureExtension
extension UnitValue: SBJTextPresentable {
	@SBJExclude
	public var presentedValue: String {
		"\(value.formatted())\(unit.symbol)"
	}

	public static var valueNomenclature: SBJNomenclature { .init(
		summary: "Numeric amount expressed in the selected unit.",
		details: "Changing the unit through UnitValueControl converts this number so the represented physical quantity is preserved.",
		accessibilityLabel: "Value"
	)}

	public static var unitNomenclature: SBJNomenclature { .init(
		summary: "Measurement unit used by this value.",
		details: "Selecting another unit converts the numeric amount rather than reinterpreting it.",
		accessibilityLabel: "Unit",
		accessibilityHint: "Changes the unit while preserving the represented quantity."
	)}
}
