import Foundation

extension MassUnit: SBJTextPresentable {
    public var abbreviation: String {
        switch self {
        case .gram: "g"
        case .kilogram: "kg"
        case .ounce: "oz"
        case .pound: "lb"
        }
    }
}
