import Foundation
import SBJDataDefinition
import SBJLocalization

extension VolumeUnit: StringPresentable {
    public var abbreviation: String {
        switch self {
        case .milliliter: "mL"
        case .liter: "L"
        case .teaspoon: "tsp"
        case .tablespoon: "tbsp"
        case .fluidOunce: "fl oz"
        case .cup: "c."
        case .pint: "pt"
        case .gallon: "gal"
        }
    }
}
