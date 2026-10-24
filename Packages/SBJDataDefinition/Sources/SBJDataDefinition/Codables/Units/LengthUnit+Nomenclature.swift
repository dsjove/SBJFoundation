import Foundation

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
