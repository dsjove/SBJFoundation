import SwiftUI
import SBJDataDefinition
import SBJLocalization

/// Shared primitive for compact icon-only actions.
///
/// Semantic wrappers choose the image, role, and accessibility wording. This
/// primitive owns the ordinary button style and compact interaction geometry so
/// callers do not need to repeat those presentation decisions.
@MainActor
public struct SBJImageButton: View {
    public let image: ImageReference
    private let role: ButtonRole?
    private let accessibilityLabel: String
    private let accessibilityHint: String?
    private let action: () -> Void

    public init(
        _ image: ImageReference,
        role: ButtonRole? = nil,
        accessibilityLabel: String,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.image = image
        self.role = role
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    /// Semantic-symbol convenience, preserving ImageReference as the general image API.
    public init(
        _ symbol: SBJSymbol,
        role: ButtonRole? = nil,
        accessibilityLabel: String,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.init(.symbol(symbol), role: role, accessibilityLabel: accessibilityLabel, accessibilityHint: accessibilityHint, action: action)
    }

    public init(
        _ symbol: SBJSymbol,
        role: ButtonRole? = nil,
        propertyInfo: SBJPropertyInfo,
        fallbackAccessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) {
        self.init(.symbol(symbol), role: role, propertyInfo: propertyInfo, fallbackAccessibilityLabel: fallbackAccessibilityLabel, action: action)
    }

    /// Creates an image button whose accessibility contract comes directly from
    /// structured model property metadata.
    public init(
        _ image: ImageReference,
        role: ButtonRole? = nil,
        propertyInfo: SBJPropertyInfo,
        fallbackAccessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) {
        self.init(
            image,
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
            Image(image)
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
