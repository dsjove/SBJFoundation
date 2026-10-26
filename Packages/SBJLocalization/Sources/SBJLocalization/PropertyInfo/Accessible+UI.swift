import SwiftUI

/// Applies a view transformation only when its optional input is present.
/// Kept private to Localization so the package does not depend on SBJFoundation.
private extension View {
    @ViewBuilder
    func applyIf2<Value, Modified: View>(
        _ value: Value?,
        transform: (Self, Value) -> Modified
    ) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}

/// Applies only specified accessibility channels, leaving unspecified channels intact.
private struct SBJAccessibleValuesModifier: ViewModifier {
    let label: String?
    let hint: String?
    let value: String?

    func body(content: Content) -> some View {
        content
            .applyIf2(label) { view, label in view.accessibilityLabel(label) }
            .applyIf2(hint) { view, hint in view.accessibilityHint(hint) }
            .applyIf2(value) { view, value in view.accessibilityValue(value) }
    }
}

private struct SBJAccessibilityModifier: ViewModifier {
    let item: AccessibleItem?

    func body(content: Content) -> some View {
        content
            .modifier(SBJAccessibleValuesModifier(
                label: item?.accessibilityLabel,
                hint: item?.accessibilityHint,
                value: item?.accessibilityValue
            ))
    }
}

public extension View {
    func accessibility(_ item: AccessibleItem?) -> some View {
        modifier(SBJAccessibilityModifier(item: item))
    }

    /// Applies declaration-site metadata without inventing a runtime value.
    func accessibility(_ info: SBJPropertyInfo) -> some View {
        accessibility(Optional(info.accessibility))
    }

    func accessibility(
        label: String? = nil,
        hint: String? = nil,
        value: String? = nil
    ) -> some View {
        modifier(SBJAccessibleValuesModifier(label: label, hint: hint, value: value))
    }
}
