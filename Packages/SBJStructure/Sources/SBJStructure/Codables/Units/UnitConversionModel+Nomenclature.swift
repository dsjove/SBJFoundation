import Foundation

extension UnitConversionModel: SBJTextPresentable {
	public var presentedValue: String {
		"\(source.value.formatted()) \(source.unit.symbol) → \(result.value.formatted()) \(destinationUnit.symbol)"
	}

	public static var sourceNomenclature: SBJNomenclature { .init(
		title: "From",
		summary: "Source measurement to convert.",
		details: "Enter a value and choose its source unit.",
		accessibilityLabel: "From value"
	)}

	public static var destinationUnitNomenclature: SBJNomenclature { .init(
		title: "To Unit",
		summary: "Destination unit for the conversion.",
		details: "Changing this unit updates the displayed result.",
		accessibilityLabel: "To unit",
		accessibilityHint: "Chooses the destination unit for the conversion."
	)}

    public static var resetNomenclature: SBJNomenclature { SBJUnitConversionNomenclature.unitsReset }

    public static var swapNomenclature: SBJNomenclature { SBJUnitConversionNomenclature.unitsSwap }

}

/// Shared nomenclature for the unit-conversion controls. This is used by
/// the UI, accessibility, and help renderer without parallel definitions.
public enum SBJUnitConversionNomenclature: SBJNomenclatureSet {
    public static let all: [String: SBJNomenclature] = [
        "units.reset": .init(title: "Reset Value", summary: "Resets the source value.", details: "The standard conversion view resets the source amount to one.", symbol: .system("1.square"), accessibilityLabel: "Reset value"),
        "units.swap": .init(title: "Swap Units", summary: "Swaps the source and destination units.", details: "The converted result becomes the new source so the represented quantity does not change.", symbol: .system("arrow.left.arrow.right"), accessibilityLabel: "Swap units"),
    ]
}
