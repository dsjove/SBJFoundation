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
    private let labeledSymbol: LabeledSymbol
    private let role: ButtonRole?
    private let accessibilityLabel: Text
    private let accessibilityHint: Text?
    private let action: () -> Void

    /// Convenience for symbols with contextual or caller-provided text.
    public init(
        _ symbol: SBJSymbol,
        role: ButtonRole? = nil,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.init(
            LabeledSymbol(
                symbol: symbol,
                accessibilityLabel: accessibilityLabel,
                accessibilityHint: accessibilityHint
            ),
            role: role,
            action: action
        )
    }

    /// Prefer package-owned definitions for actions with stable meaning.
    public init(
        _ definition: LabeledSymbol,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.symbol = definition.symbol
        self.labeledSymbol = definition
        self.role = role
        let label = definition.accessibilityLabel ?? definition.title ?? "Button"
        self.accessibilityLabel = Text(verbatim: label)
        self.accessibilityHint = definition.accessibilityHint.map { Text(verbatim: $0) }
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
            Label(labeledSymbol)
                .labelStyle(.iconOnly)
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
