/// Internal editor rendering mode. Model units are immutable; all automatic
/// unit-value fields select `.fixedUnit`.
public enum SBJUnitValueEditorMode: Sendable, Hashable {
    case editable
    case fixedUnit
}

#if !os(tvOS) && !os(watchOS)
import SwiftUI

protocol _SBJUnitValueEditorValue {
    @MainActor
    static func _sbjMakeUnitValueEditor(
        label: String,
        binding: SBJAnyBinding,
        labelIsUnknown: Bool,
        editor: SBJUnitValueEditorMode
    ) -> AnyView
}

extension UnitValue: _SBJUnitValueEditorValue {
    @MainActor
    static func _sbjMakeUnitValueEditor(
        label: String,
        binding: SBJAnyBinding,
        labelIsUnknown: Bool,
        editor: SBJUnitValueEditorMode
    ) -> AnyView {
        AnyView(
            SBJUnitValueEditor(
                label: label,
                value: binding.binding(as: Self.self),
                labelIsUnknown: labelIsUnknown,
                editor: editor
            )
        )
    }
}

extension UnitValue: SBJTypedEditorValue {}

struct SBJUnitValueEditor<Unit: UnitType>: View {
    let label: String
    @Binding var value: UnitValue<Unit>
    let labelIsUnknown: Bool
    let editor: SBJUnitValueEditorMode

    var body: some View {
        SBJEditorLabeledField(label: label, labelIsUnknown: labelIsUnknown) {
            UnitValueControl(
                value: $value,
                accessibilityLabel: label,
                unitEditable: editor == .editable
            )
        }
    }
}
#endif
