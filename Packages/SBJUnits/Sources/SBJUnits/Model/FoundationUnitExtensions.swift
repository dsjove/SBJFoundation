import Foundation

public extension UnitLength {
    /// PDF/Core Graphics point: 72 points per inch.
    static let sbjPoints = UnitLength(
        symbol: "pt",
        converter: UnitConverterLinear(coefficient: 0.0254 / 72.0)
    )
}

public extension UnitDuration {
    static let sbjDays = UnitDuration(
        symbol: "day",
        converter: UnitConverterLinear(coefficient: 86_400)
    )
}
