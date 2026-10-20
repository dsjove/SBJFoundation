#if !os(tvOS) && !os(watchOS)
import SwiftUI

import SBJDataDefinition
/// Text-input configuration is explicit at the control boundary; no custom
/// EnvironmentValues are installed in the view tree.
extension View {
    public func sbjApplyTextInputPolicies(
        autocorrection: SBJTextAutocorrection,
        capitalization: SBJTextCapitalization
    ) -> some View {
        modifier(SBJTextInputPolicyModifier(
            autocorrection: autocorrection,
            capitalization: capitalization
        ))
    }
}

private struct SBJTextInputPolicyModifier: ViewModifier {
    let autocorrection: SBJTextAutocorrection
    let capitalization: SBJTextCapitalization

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
