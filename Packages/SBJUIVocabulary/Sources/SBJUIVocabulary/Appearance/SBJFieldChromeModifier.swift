import SwiftUI

private struct SBJFieldChromeModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    let state: SBJFieldChromeState

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: SBJUIAppearance.fieldCornerRadius)
                    .fill(backgroundColor)
            }
            .overlay {
                RoundedRectangle(cornerRadius: SBJUIAppearance.fieldCornerRadius)
                    .stroke(
                        SBJFieldChromeStroke.color(for: state, contrast: colorSchemeContrast),
                        lineWidth: SBJFieldChromeStroke.width(for: state, contrast: colorSchemeContrast)
                    )
                    .allowsHitTesting(false)
            }
    }

    private var backgroundColor: Color {
        if state.contains(.selected) { return SBJUIAppearance.activeControlColor }
#if os(tvOS) || os(watchOS)
        return .clear
#else
        return Color(.systemBackground)
#endif
    }
}

/// Centralized stroke precedence: invalid > focused > selected > standard.
private enum SBJFieldChromeStroke {
    static func color(for state: SBJFieldChromeState, contrast: ColorSchemeContrast) -> Color {
        if state.contains(.invalid) { return SBJUIAppearance.invalidColor }
        if state.contains(.focused) { return SBJUIAppearance.focusColor }
        if state.contains(.selected) { return SBJUIAppearance.activeControlColor }
        return SBJUIAppearance.fieldBorderColor(contrast)
    }

    static func width(for state: SBJFieldChromeState, contrast: ColorSchemeContrast) -> CGFloat {
        if state.contains(.focused) { return SBJUIAppearance.focusThickness(contrast) }
        return SBJUIAppearance.borderThickness(contrast)
    }
}

/// Standalone invalid outline for controls that do not own their field-chrome state.
/// Shares stroke decisions with the field-chrome modifier.
private struct SBJInvalidFieldOutlineModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    let isInvalid: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if isInvalid {
                RoundedRectangle(cornerRadius: SBJUIAppearance.fieldCornerRadius)
                    .stroke(
                        SBJFieldChromeStroke.color(for: .invalid, contrast: colorSchemeContrast),
                        lineWidth: SBJFieldChromeStroke.width(for: .invalid, contrast: colorSchemeContrast)
                    )
                    .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    func sbjFieldChrome(_ state: SBJFieldChromeState = .standard) -> some View {
        modifier(SBJFieldChromeModifier(state: state))
    }
}

public extension View {
    /// Draws the shared invalid-field outline on views that do not supply chrome state.
    func invalidDecoration(_ isInvalid: Bool = true) -> some View {
        modifier(SBJInvalidFieldOutlineModifier(isInvalid: isInvalid))
    }
}
