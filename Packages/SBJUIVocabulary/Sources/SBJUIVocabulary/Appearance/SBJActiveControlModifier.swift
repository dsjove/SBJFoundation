import SwiftUI

private struct SBJActiveControlModifier: ViewModifier {
    let isSelected: Bool
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .foregroundStyle(
                isSelected
                    ? SBJUIAppearance.activeControlForegroundColor
                    : .primary
            )
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: SBJUIAppearance.singleLineFieldMinimumHeight)
            .sbjFieldChrome(isSelected ? .selected : .standard)
            .contentShape(RoundedRectangle(cornerRadius: SBJUIAppearance.fieldCornerRadius))
    }
}

public extension View {
    /// Gives a compact interactive control the standard SBJ field chrome.
    func sbjActiveControl(
        isSelected: Bool = false,
        horizontalPadding: CGFloat = 7,
        verticalPadding: CGFloat = 4
    ) -> some View {
        modifier(
            SBJActiveControlModifier(
                isSelected: isSelected,
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding
            )
        )
    }
}
