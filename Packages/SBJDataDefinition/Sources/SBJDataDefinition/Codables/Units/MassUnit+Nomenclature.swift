import Foundation

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
