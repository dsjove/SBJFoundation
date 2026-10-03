#if !os(tvOS) && !os(watchOS)
import SwiftUI

private struct SBJTextAutocorrectionKey: EnvironmentKey {
    static let defaultValue: SBJTextAutocorrection = .automatic
}

private struct SBJTextCapitalizationKey: EnvironmentKey {
    static let defaultValue: SBJTextCapitalization = .automatic
}

extension EnvironmentValues {
    var sbjTextAutocorrection: SBJTextAutocorrection {
        get { self[SBJTextAutocorrectionKey.self] }
        set { self[SBJTextAutocorrectionKey.self] = newValue }
    }

    var sbjTextCapitalization: SBJTextCapitalization {
        get { self[SBJTextCapitalizationKey.self] }
        set { self[SBJTextCapitalizationKey.self] = newValue }
    }
}

extension View {
    func sbjTextInputPolicies(
        autocorrection: SBJTextAutocorrection,
        capitalization: SBJTextCapitalization
    ) -> some View {
        environment(\.sbjTextAutocorrection, autocorrection)
            .environment(\.sbjTextCapitalization, capitalization)
    }

    func sbjApplyTextInputPolicies() -> some View {
        modifier(SBJTextInputPolicyModifier())
    }
}

private struct SBJTextInputPolicyModifier: ViewModifier {
    @Environment(\.sbjTextAutocorrection) private var autocorrection
    @Environment(\.sbjTextCapitalization) private var capitalization

    @ViewBuilder
    func body(content: Content) -> some View {
        let capitalized = content.textInputAutocapitalization(capitalization.swiftUIValue)
        switch autocorrection {
        case .automatic:
            capitalized
        case .enabled:
            capitalized.autocorrectionDisabled(false)
        case .disabled:
            capitalized.autocorrectionDisabled(true)
        }
    }
}

private extension SBJTextCapitalization {
    var swiftUIValue: TextInputAutocapitalization? {
        switch self {
        case .automatic: nil
        case .never: .never
        case .words: .words
        case .sentences: .sentences
        case .characters: .characters
        }
    }
}
#endif
