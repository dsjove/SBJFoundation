import Foundation

@SBJStructureExtension
extension UnitEditingPolicy: SBJTextPresentable {
	@SBJExclude
	public var presentedValue: String {
		"Step: \(defaultStep.formatted())"
	}

	public static var defaultStepNomenclature: SBJNomenclature { .init(
		title: "Default Step",
		summary: "Default increment used when stepping a unit value.",
		details: "Per-unit overrides take precedence. Non-finite or non-positive steps are ignored."
	)}

	public static var overridesNomenclature: SBJNomenclature { .init(
		title: "Unit Step Overrides",
		summary: "Per-unit editing increments.",
		details: "Each entry replaces the default step for that unit."
	)}
}
