import SwiftUI
import SBJDataDefinition

/// Shared primitive for compact symbol-only actions.
///
/// Semantic wrappers choose the image, role, and accessibility wording. This
/// primitive owns the ordinary button style and compact interaction geometry so
/// callers do not need to repeat those presentation decisions.
@MainActor
public struct SBJSymbolButton: View {
    public let symbol: SBJSymbol
    private let role: ButtonRole?
    private let accessibilityLabel: String
    private let accessibilityHint: String?
    private let action: () -> Void

    public init(
        _ symbol: SBJSymbol,
        role: ButtonRole? = nil,
        accessibilityLabel: String,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.symbol = symbol
        self.role = role
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    /// Derive the accessibility contract from structured property metadata.
    public init(
        _ symbol: SBJSymbol,
        role: ButtonRole? = nil,
        propertyInfo: SBJPropertyInfo,
        fallbackAccessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) {
        self.init(
            symbol,
            role: role,
            accessibilityLabel: propertyInfo.accessibilityLabel
                ?? propertyInfo.title
                ?? fallbackAccessibilityLabel
                ?? propertyInfo.summary
                ?? "Button",
            accessibilityHint: propertyInfo.accessibilityHint ?? propertyInfo.summary
                ?? "Button",
            action: action
        )
    }

    public var body: some View {
        Button(role: role, action: action) {
            Image(symbol: symbol)
                .frame(
                    minWidth: SBJUIAppearance.compactButtonMinimumSize,
                    minHeight: SBJUIAppearance.compactButtonMinimumSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(accessibilityLabel)
        .applyIf(accessibilityHint) { view, hint in
            view.accessibilityHint(hint)
        }
    }
}
