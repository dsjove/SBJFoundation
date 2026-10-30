import Foundation

/// Describes a user-interface action or meaningful label with a required title and symbol.
///
/// `title` is the human-readable semantic name even when the presentation hides its text
/// (for example, an icon-only button). Do not use this type for decorative symbols;
/// use `SBJSymbol` directly instead. Use `SBJPropertyInfo` for data-definition metadata.
///
/// Accessibility is applied by the consuming view or control, not by this definition:
/// - For a standalone label, its visible title normally provides the accessible name.
/// - For an interactive control, the control owns the accessible name and hint.
/// - For a label associated with a separate control, associate them and avoid duplicate
///   VoiceOver announcements.
/// - Hide purely decorative imagery from accessibility.
///
/// These semantic conventions are not enforceable by the Swift type system.
public struct SBJLabeledSymbol: Hashable, Sendable {
    /// Required semantic name of the action or label, including when text is hidden.
    /// Supply meaningful, nonempty text; a nonempty value is a usage convention.
    public let title: String

    /// Required image used to present the action or label; not a replacement for its title.
    public let symbol: SBJSymbol

    /// Optional accessible-name override when `title` is insufficient or ambiguous.
    /// Consumers normally use `accessibilityLabel ?? title` on the actual control.
    public let accessibilityLabel: String?

    /// Optional non-obvious interaction explanation, applied by the consuming control.
    /// Do not repeat the title or announce the control's role (such as "button").
    public let accessibilityHint: String?

    /// Creates a UI definition; `title` is always required, including for icon-only controls.
    public init(
        symbol: SBJSymbol,
        title: String,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil
    ) {
        self.symbol = symbol
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }
}
