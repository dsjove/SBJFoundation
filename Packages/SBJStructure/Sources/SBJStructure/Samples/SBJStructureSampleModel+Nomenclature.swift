#if DEBUG
import SBJLocalization

@SBJStructureExtension
extension SBJStructureSampleModel {
	public static let courseNomenclature = #SBJAutoNomenclature(summary: "The course where this recipe is normally served."
    )

    public static let servingsNomenclature = #SBJAutoNomenclature(summary: "The number of portions the recipe is intended to make.",
		details: "The structural constraint is 1 through 24. The editor uses that domain knowledge to keep this numeric field compact without fixing it to one point size.",
		accessibilityLabel: "Recipe servings",
		accessibilityHint: "Enter the number of portions this recipe makes"
	)

	public static let lastMadeNomenclature = #SBJAutoNomenclature(summary: "Optional date of the most recent preparation.",
		details: "The system date editor follows the user's locale and calendar preferences."
	)

	public static let customPreparationMetadata = SBJNomenclature(
		summary: "Time spent preparing ingredients before cooking."
	)

	public static func propertyNomenclature<Value>(for keyPath: KeyPath<SBJStructureSampleModel, Value>) -> SBJNomenclature? {
		if keyPath == \SBJStructureSampleModel.preparationMinutes {
			return SBJNomenclatureResolver.resolve(customPreparationMetadata, for: Value.self)
		}
		return SBJNomenclatureResolver.resolve(_extensionNomenclature(for: keyPath), for: Value.self)
	}
}

#endif
