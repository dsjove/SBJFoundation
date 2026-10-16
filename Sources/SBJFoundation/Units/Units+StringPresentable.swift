import Foundation
import SBJLocalization

extension MeasurementSystem: StringPresentable {}

extension MassUnit: StringPresentable {
    public var abbreviation: String {
        switch self {
        case .gram: "g"
        case .kilogram: "kg"
        case .ounce: "oz"
        case .pound: "lb"
        }
    }
}

extension UnitCategory: StringPresentable {}

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

extension LengthUnit: StringPresentable {
    public var abbreviation: String {
        switch self {
        case .point: "pt"
        case .millimeter: "mm"
        case .centimeter: "cm"
        case .meter: "m"
        case .kilometer: "km"
        case .inch: "in"
        case .foot: "ft"
        case .yard: "yd"
        case .mile: "mi"
        }
    }
}
