import SwiftUI

/// Shared visual vocabulary for SBJFoundation controls and consuming applications.
///
/// Semantic colors live here instead of at their call sites so a state such as
/// validation failure, focus, or an active search filter has one visual meaning
/// throughout the framework. Accessibility appearance preferences are handled
/// here as part of that vocabulary rather than defining the vocabulary itself.
public enum SBJUIAppearance {
    // MARK: - Semantic colors

    public static var invalidColor: Color { .red }
    public static var issueColor: Color { invalidColor }
    public static var changedColor: Color { .accentColor }
    public static var emptyColor: Color { .secondary }
    public static var activeControlColor: Color { .accentColor }
    public static var activeControlForegroundColor: Color { .white }
    public static var searchActiveColor: Color { .blue }
    public static var focusColor: Color { .accentColor }
    public static var inactiveControlColor: Color { .secondary }
    public static var interactiveColor: Color { .accentColor }

    public static func fieldBorderColor(_ contrast: ColorSchemeContrast) -> Color {
        Color.secondary.opacity(secondaryStrokeOpacity(contrast))
    }

    public static func subtleStrokeColor(_ contrast: ColorSchemeContrast) -> Color {
        Color.secondary.opacity(subtleStrokeOpacity(contrast))
    }

    public static func hierarchyCueColor(_ contrast: ColorSchemeContrast) -> Color {
        Color.secondary.opacity(hierarchyCueOpacity(contrast))
    }

    public static func headerFillColor(_ contrast: ColorSchemeContrast) -> Color {
        Color.secondary.opacity(headerFillOpacity(contrast))
    }

    public static func invalidFillColor(_ contrast: ColorSchemeContrast) -> Color {
        invalidColor.opacity(invalidFillOpacity(contrast))
    }

    public static func focusStrokeColor(_ contrast: ColorSchemeContrast) -> Color {
        focusColor.opacity(contrast == .increased ? 0.85 : 0.5)
    }

    public static func focusShadowColor(reduceTransparency: Bool) -> Color {
        reduceTransparency ? .clear : focusColor.opacity(0.25)
    }

    static var filteredEmptyFillColor: Color {
        Color.secondary.opacity(0.08)
    }

    // MARK: - Accessibility-sensitive chrome

    public static func secondaryStrokeOpacity(_ contrast: ColorSchemeContrast) -> Double {
        contrast == .increased ? 0.90 : 0.65
    }

    public static func subtleStrokeOpacity(_ contrast: ColorSchemeContrast) -> Double {
        contrast == .increased ? 0.80 : 0.55
    }

    public static func hierarchyCueOpacity(_ contrast: ColorSchemeContrast) -> Double {
        contrast == .increased ? 0.75 : 0.48
    }

    public static func headerFillOpacity(_ contrast: ColorSchemeContrast) -> Double {
        contrast == .increased ? 0.16 : 0.08
    }

    public static func invalidFillOpacity(_ contrast: ColorSchemeContrast) -> Double {
        contrast == .increased ? 0.18 : 0.10
    }

    public static func borderThickness(_ contrast: ColorSchemeContrast) -> Double {
        contrast == .increased ? 1.5 : 1.0
    }

    public static func focusThickness(_ contrast: ColorSchemeContrast) -> Double {
        contrast == .increased ? 3.0 : 2.0
    }

    // MARK: - Common field geometry

    public static let fieldCornerRadius: Double = 6.0
    public static let selectionCornerRadius: Double = 8.0
    public static let transientSelectionCornerRadius: Double = 6.0
    public static let singleLineFieldMinimumHeight: Double = 24.0
    public static let compactButtonMinimumSize: Double = 24.0
}
