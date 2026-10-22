import SBJDataDefinition
import SBJLocalization

@SBJPropertyInfo
extension SBJStructureSampleModel {
	public static let servingsInfo = SBJPropertyInfo(
		summary: "The number of portions the recipe is intended to make.",
		details: "The structural constraint is 1 through 24. The editor uses that domain knowledge to keep this numeric field compact without fixing it to one point size.",
		accessibilityLabel: "Recipe servings",
		accessibilityHint: "Enter the number of portions this recipe makes"
	)

	public static let lastMadeInfo = SBJPropertyInfo(
		summary: "Optional date of the most recent preparation.",
		details: "The system date editor follows the user's locale and calendar preferences."
	)

	public static let customPreparationMetadata = SBJPropertyInfo(
		summary: "Time spent preparing ingredients before cooking."
	)

	static func propertyInfo<Value>(for keyPath: KeyPath<SBJStructureSampleModel, Value>) -> SBJPropertyInfo? {
		if keyPath == \SBJStructureSampleModel.preparationMinutes {
			return customPreparationMetadata
		}
		return _extensionPropertyInfo(for: keyPath)
	}
}
