import Foundation
import SBJDataDefinition
import SBJLocalization

extension UnitEditingPolicy: StringPresentable {
    public var description: String {
        "Step: \(defaultStep.formatted())"
    }

    public static var defaultStepInfo: SBJPropertyInfo {
        SBJPropertyInfo(
                title: "Default Step",
                summary: "Default increment used when stepping a unit value.",
                details: "Per-unit overrides take precedence. Non-finite or non-positive steps are ignored."
            )
    }

    public static var overridesInfo: SBJPropertyInfo {
        SBJPropertyInfo(
                title: "Unit Step Overrides",
                summary: "Per-unit editing increments.",
                details: "Each entry replaces the default step for that unit."
            )
    }

}
