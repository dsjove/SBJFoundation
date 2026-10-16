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
                    .stroke(strokeColor, lineWidth: strokeWidth)
                    .allowsHitTesting(false)
            }
    }

    private var backgroundColor: Color {
        if state == .selected {
            return SBJUIAppearance.activeControlColor
        }
#if os(tvOS) || os(watchOS)
        return .clear
#else
        return Color(.systemBackground)
#endif
    }

    private var strokeColor: Color {
        switch state {
        case .standard:
            SBJUIAppearance.fieldBorderColor(colorSchemeContrast)
        case .focused:
            SBJUIAppearance.focusColor
        case .selected:
            SBJUIAppearance.activeControlColor
        }
    }

    private var strokeWidth: CGFloat {
        switch state {
        case .focused:
            SBJUIAppearance.focusThickness(colorSchemeContrast)
        case .standard, .selected:
            SBJUIAppearance.borderThickness(colorSchemeContrast)
        }
    }
}

extension View {
    func sbjFieldChrome(_ state: SBJFieldChromeState = .standard) -> some View {
        modifier(SBJFieldChromeModifier(state: state))
    }
}
