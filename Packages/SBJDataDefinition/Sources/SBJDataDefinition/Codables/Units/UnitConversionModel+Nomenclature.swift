import Foundation

extension UnitConversionModel: SBJTextPresentable {
	public var presentedValue: String {
		"\(source.value.formatted()) \(source.unit.symbol) → \(result.value.formatted()) \(destinationUnit.symbol)"
	}

	public static var sourceInfo: SBJPropertyInfo { .init(
		title: "From",
		summary: "Source measurement to convert.",
		details: "Enter a value and choose its source unit.",
		accessibilityLabel: "From value"
	)}

	public static var destinationUnitInfo: SBJPropertyInfo { .init(
		title: "To Unit",
		summary: "Destination unit for the conversion.",
		details: "Changing this unit updates the displayed result.",
		accessibilityLabel: "To unit",
		accessibilityHint: "Chooses the destination unit for the conversion."
	)}

	public static var resetInfo: SBJPropertyInfo { .init(
		title: "Reset Value",
		summary: "Resets the source value.",
		details: "The standard conversion view resets the source amount to one.",
		accessibilityLabel: "Reset value"
	)}

	public static var swapInfo: SBJPropertyInfo { .init(
		title: "Swap Units",
		summary: "Swaps the source and destination units.",
		details: "The converted result becomes the new source so the represented quantity does not change.",
		accessibilityLabel: "Swap units"
	)}
}
