import SwiftUI

/// Shared primitive for compact symbol-only actions.
///
/// Semantic wrappers choose the image, role, and accessibility wording. This
/// primitive owns the ordinary button style and compact interaction geometry so
/// callers do not need to repeat those presentation decisions.
@MainActor
public struct SBJSymbolButton: View {
    public let symbol: SBJSymbol
    private let labeledSymbol: SBJLabeledSymbol
    private let role: ButtonRole?
    private let accessibilityLabel: Text
    private let accessibilityHint: Text?
    private let action: () -> Void

    /// Convenience for icon-only actions with an explicit meaningful accessible name.
    /// The accessible name also serves as the semantic title of this action.
    /// Use a `SBJLabeledSymbol` when the visual title and accessible name differ.
    public init(
        _ symbol: SBJSymbol,
        role: ButtonRole? = nil,
        accessibilityLabel: String,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.init(
            SBJLabeledSymbol(
                symbol: symbol,
                title: accessibilityLabel,
                accessibilityLabel: accessibilityLabel,
                accessibilityHint: accessibilityHint
            ),
            role: role,
            action: action
        )
    }

    /// Prefer package-owned definitions for actions with stable meaning.
    /// The button, rather than its `Label`, owns the accessible name and hint.
    /// The required title is used whenever no accessible-name override is supplied.
    public init(
        _ definition: SBJLabeledSymbol,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.symbol = definition.symbol
        self.labeledSymbol = definition
        self.role = role
        let label = definition.accessibilityLabel ?? definition.title
        self.accessibilityLabel = Text(verbatim: label)
        self.accessibilityHint = definition.accessibilityHint.map { Text(verbatim: $0) }
        self.action = action
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
