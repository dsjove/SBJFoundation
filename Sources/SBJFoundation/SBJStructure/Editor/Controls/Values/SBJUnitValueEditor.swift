#if !os(tvOS) && !os(watchOS)
import SwiftUI

protocol _SBJUnitValueEditorValue {
    @MainActor
    static func _sbjMakeUnitValueEditor(
        label: String,
        binding: SBJAnyBinding,
        labelIsUnknown: Bool
    ) -> AnyView
}

extension UnitValue: _SBJUnitValueEditorValue {
    @MainActor
    static func _sbjMakeUnitValueEditor(
        label: String,
        binding: SBJAnyBinding,
        labelIsUnknown: Bool
    ) -> AnyView {
        AnyView(
            SBJUnitValueEditor(
                label: label,
                value: binding.binding(as: Self.self),
                labelIsUnknown: labelIsUnknown
            )
        )
    }
}

extension UnitValue: SBJTypedEditorValue {}

struct SBJUnitValueEditor<Unit: UnitType>: View {
    let label: String
    @Binding var value: UnitValue<Unit>
    let labelIsUnknown: Bool

    var body: some View {
        SBJEditorLabeledField(label: label, labelIsUnknown: labelIsUnknown) {
            UnitValueControl(
                value: $value,
                accessibilityLabel: label
            )
        }
    }
}
#endif
