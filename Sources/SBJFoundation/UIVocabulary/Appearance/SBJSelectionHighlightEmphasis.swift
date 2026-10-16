import SwiftUI

extension SBJUIAppearance {
    public static var selectionColor: Color { Self.searchActiveColor }

    public static func selectionFillColor(
        _ contrast: ColorSchemeContrast,
        emphasis: SBJSelectionHighlightEmphasis = .selection
    ) -> Color {
        selectionColor.opacity(selectionFillOpacity(contrast, emphasis: emphasis))
    }

    public static func selectionStrokeColor(
        _ contrast: ColorSchemeContrast,
        emphasis: SBJSelectionHighlightEmphasis = .selection
    ) -> Color {
        selectionColor.opacity(selectionStrokeOpacity(contrast, emphasis: emphasis))
    }

	public static func selectionFillOpacity(
        _ contrast: ColorSchemeContrast,
        emphasis: SBJSelectionHighlightEmphasis = .selection
    ) -> Double {
        selectionFillOpacity(
            increasedContrast: contrast == .increased,
            emphasis: emphasis
        )
    }

    public static func selectionFillOpacity(
        increasedContrast: Bool,
        emphasis: SBJSelectionHighlightEmphasis = .selection
    ) -> Double {
        switch emphasis {
        case .selection:
            return increasedContrast ? 0.18 : 0.12
        case .transient:
            return increasedContrast ? 0.32 : 0.25
        }
    }

    public static func selectionStrokeOpacity(
        _ contrast: ColorSchemeContrast,
        emphasis: SBJSelectionHighlightEmphasis = .selection
    ) -> Double {
        selectionStrokeOpacity(
            increasedContrast: contrast == .increased,
            emphasis: emphasis
        )
    }

    public static func selectionStrokeOpacity(
        increasedContrast: Bool,
        emphasis: SBJSelectionHighlightEmphasis = .selection
    ) -> Double {
        switch emphasis {
        case .selection:
            return 1.0
        case .transient:
            return increasedContrast ? 0.90 : 0.75
        }
    }

    public static func selectionStrokeThickness(
        _ contrast: ColorSchemeContrast,
        emphasis: SBJSelectionHighlightEmphasis = .selection
    ) -> Double {
        selectionStrokeThickness(
            increasedContrast: contrast == .increased,
            emphasis: emphasis
        )
    }

    public static func selectionStrokeThickness(
        increasedContrast: Bool,
        emphasis: SBJSelectionHighlightEmphasis = .selection
    ) -> Double {
        switch emphasis {
        case .selection:
            return increasedContrast ? 3.0 : 2.0
        case .transient:
            return increasedContrast ? 5.0 : 4.0
        }
    }
}

/// The visual emphasis used for a selected or temporarily highlighted item.
///
/// Both SwiftUI selection chrome and non-SwiftUI renderers can use the same
/// appearance values from `SBJUIAppearance` for these semantic states.
public enum SBJSelectionHighlightEmphasis: Sendable {
    /// Persistent selection, such as the currently selected row.
    case selection

    /// Short-lived emphasis used to reveal the corresponding content elsewhere.
    case transient
}

private struct SelectionHighlightModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    let isHighlighted: Bool
    let emphasis: SBJSelectionHighlightEmphasis
    let cornerRadius: Double?

    func body(content: Content) -> some View {
        let radius = cornerRadius ?? SBJUIAppearance.selectionCornerRadius

        content
            .background {
                RoundedRectangle(cornerRadius: radius)
                    .fill(
                        isHighlighted
                            ? SBJUIAppearance.selectionFillColor(colorSchemeContrast, emphasis: emphasis)
                            : .clear
                    )
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .stroke(
                        isHighlighted
                            ? SBJUIAppearance.selectionStrokeColor(colorSchemeContrast, emphasis: emphasis)
                            : .clear,
                        lineWidth: isHighlighted
                            ? SBJUIAppearance.selectionStrokeThickness(colorSchemeContrast, emphasis: emphasis)
                            : 0
                    )
                    .allowsHitTesting(false)
            }
    }
}

public extension View {
    /// Applies the standard SBJ selection/highlight chrome without imposing
    /// domain-specific behavior or focus semantics.
    func sbjSelectionHighlight(
        _ isHighlighted: Bool = true,
        emphasis: SBJSelectionHighlightEmphasis = .selection,
        cornerRadius: Double? = nil
    ) -> some View {
        modifier(
            SelectionHighlightModifier(
                isHighlighted: isHighlighted,
                emphasis: emphasis,
                cornerRadius: cornerRadius
            )
        )
    }
}
