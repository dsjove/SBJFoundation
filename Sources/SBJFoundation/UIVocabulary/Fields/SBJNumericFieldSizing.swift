import Foundation
import SwiftUI

/// Domain-informed sizing for compact scalar controls.
///
/// The numbers here are nominal body-text dimensions, not rigid screen-space
/// widths. ``SBJPreferredFieldWidthModifier`` scales them with Dynamic Type.
/// The finite maximum keeps small-domain controls compact in wide editors,
/// while the scaled range still leaves room for larger fonts and localized
/// punctuation.
enum SBJNumericFieldSizing {
    static let unboundedInteger = SBJFieldSizing(minimum: 88, ideal: 120, maximum: 168)
    static let unboundedNumber = SBJFieldSizing(minimum: 96, ideal: 140, maximum: 196)

    static func integer(range: ClosedRange<Int>?, locale: Locale) -> SBJFieldSizing {
        guard let range, range.upperBound != Int.max else {
            return unboundedInteger
        }

        let lower = range.lowerBound.formatted(.number.locale(locale))
        let upper = range.upperBound.formatted(.number.locale(locale))
        return boundedSizing(
            characterCount: max(lower.count, upper.count),
            minimum: 64,
            maximum: 176
        )
    }

    static func number(range: ClosedRange<Double>?, locale: Locale) -> SBJFieldSizing {
        guard let range, range.upperBound != Double.greatestFiniteMagnitude else {
            return unboundedNumber
        }

        let lower = range.lowerBound.formatted(.number.locale(locale))
        let upper = range.upperBound.formatted(.number.locale(locale))
        return boundedSizing(
            characterCount: max(lower.count, upper.count),
            minimum: 80,
            maximum: 208
        )
    }

    private static func boundedSizing(
        characterCount: Int,
        minimum: CGFloat,
        maximum: CGFloat
    ) -> SBJFieldSizing {
        // This estimate is only a preference. The actual values are scaled by
        // Dynamic Type and deliberately provide headroom for localized glyphs.
        let ideal = min(maximum, max(minimum, CGFloat(characterCount) * 10 + 28))
        return SBJFieldSizing(
            minimum: max(minimum, ideal * 0.78),
            ideal: ideal,
            maximum: min(maximum, max(ideal, ideal * 1.30))
        )
    }
}
