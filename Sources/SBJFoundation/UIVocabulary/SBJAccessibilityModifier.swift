import SwiftUI
import SBJSubject

private struct SBJAccessibilityModifier: ViewModifier {
    let item: any Accessible

    func body(content: Content) -> some View {
        content
            .applyIf(item.accessibilityLabel) { view, label in
                view.accessibilityLabel(label)
            }
            .applyIf(item.accessibilityHint) { view, hint in
                view.accessibilityHint(hint)
            }
            .applyIf(item.accessibilityValue) { view, value in
                view.accessibilityValue(value)
            }
    }
}

public extension View {
    func accessibility(_ item: any Accessible) -> some View {
        modifier(SBJAccessibilityModifier(item: item))
    }

    func accessibility(
        label: String? = nil,
        hint: String? = nil,
        value: String? = nil
    ) -> some View {
        accessibility(AccessibleItem(
            label: label,
            hint: hint,
            value: value
        ))
    }
}
