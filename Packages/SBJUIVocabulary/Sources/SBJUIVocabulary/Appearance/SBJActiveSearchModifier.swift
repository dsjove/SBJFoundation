import SwiftUI

import SBJDataDefinition
private struct SBJActiveSearchModifier: ViewModifier {
    let isActive: Bool
    let padding: CGFloat?

    func body(content: Content) -> some View {
        if let padding {
            content
                .padding(padding)
                .overlay {
                RoundedRectangle(cornerRadius: SBJUIAppearance.activeSearchCornerRadius)
                    .stroke(
                        style: StrokeStyle(
                            lineWidth: isActive ? SBJUIAppearance.activeSearchStrokeWidth : 0,
                            lineCap: .round,
                            dash: SBJUIAppearance.activeSearchDash
                        )
                    )
                    .foregroundStyle(isActive ? SBJUIAppearance.searchActiveColor : .clear)
                    .allowsHitTesting(false)
                }
        } else {
            content
        }
    }
}

public extension View {
    /// Applies the shared visual treatment for search/filter controls.
    ///
    /// A non-nil padding adds the inset and active-search outline; nil omits
    /// both, leaving the underlying view undecorated.
    func sbjActiveSearch(_ isActive: Bool = true, padding: CGFloat? = 8) -> some View {
        modifier(SBJActiveSearchModifier(isActive: isActive, padding: padding))
    }
}
