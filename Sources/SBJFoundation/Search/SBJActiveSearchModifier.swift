import SwiftUI

private struct SBJActiveSearchModifier: ViewModifier {
    let isActive: Bool
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        style: StrokeStyle(
                            lineWidth: isActive ? 2 : 0,
                            lineCap: .round,
                            dash: [6, 3]
                        )
                    )
                    .foregroundStyle(isActive ? SBJUIAppearance.searchActiveColor : .clear)
                    .allowsHitTesting(false)
            }
    }
}

public extension View {
    /// Applies the shared visual treatment for search/filter controls.
    ///
    /// The modifier owns both the inset around the controls and the active
    /// decoration so the decorated region has consistent geometry wherever it
    /// is used. Callers decide what constitutes an active search and which
    /// region of UI belongs to the search criteria.
    func sbjActiveSearch(_ isActive: Bool = true, padding: CGFloat = 8) -> some View {
        modifier(SBJActiveSearchModifier(isActive: isActive, padding: padding))
    }
}
