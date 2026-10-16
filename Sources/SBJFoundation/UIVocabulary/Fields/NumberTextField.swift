import SwiftUI

/// The reusable SBJ integer text field.
///
/// `NumberTextField` is a standalone input control. Surrounding labels, status,
/// accessibility metadata, and companion controls remain outside this component.
///
/// Range semantics deliberately match `@SBJInteger`: a range describes validity, not
/// normalization. Typing or binding an out-of-range value does not silently clamp it;
/// the field shows the standard invalid chrome so the value can be inspected and fixed.
/// This avoids the previous split where the standalone field silently clamped/defaulted
/// input while the owning interface preserved invalid values.
@MainActor
public struct NumberTextField: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>?
    private let focusBinding: FocusState<Bool>.Binding?

    @Environment(\.locale) private var locale

    /// Creates a reusable integer field.
    ///
    /// - Parameters:
    ///   - title: Placeholder/title text. This remains `String` until the shared
    ///     localization-resource design is implemented; see Documentation/LOCALIZATION_AND_PRESENTATION_RESOURCES.md.
    ///   - value: The integer binding.
    ///   - range: Optional validity range. Values outside it are shown as invalid and are
    ///     not silently clamped.
    public init(
        _ title: String = "",
        value: Binding<Int>,
        in range: ClosedRange<Int>? = nil
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.focusBinding = nil
    }

    /// Convenience for a lower-bounded integer field.
    public init(
        _ title: String = "",
        value: Binding<Int>,
        lowerBound: Int
    ) {
        self.init(title, value: value, in: lowerBound...Int.max)
    }

    /// Internal initializer that lets an owning view participate in
    /// programmatic focus without duplicating the numeric field implementation.
    init(
        _ title: String = "",
        value: Binding<Int>,
        in range: ClosedRange<Int>? = nil,
        isFocused: FocusState<Bool>.Binding
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.focusBinding = isFocused
    }

    public var body: some View {
        Group {
            if let focusBinding {
                field.oneLiner(isFocused: focusBinding)
            } else {
                field.oneLiner()
            }
        }
        .multilineTextAlignment(.trailing)
        .sbjPreferredFieldWidth(SBJNumericFieldSizing.integer(range: range, locale: locale))
        .invalidDecoration(range.map { !$0.contains(value) } ?? false)
#if os(iOS)
        .keyboardType(keyboardType)
#endif
    }

    private var field: some View {
        // Explicitly use the effective SwiftUI locale rather than Locale.current so
        // previews, document contexts, and future localization overrides remain coherent.
        // Grouping is disabled for editing even when the locale normally groups numbers.
        TextField(
            title,
            value: $value,
            format: .number
                .grouping(.never)
                .locale(locale)
        )
    }

#if os(iOS)
    private var keyboardType: UIKeyboardType {
        (range?.lowerBound ?? Int.min) >= 0 ? .numberPad : .numbersAndPunctuation
    }
#endif
}
