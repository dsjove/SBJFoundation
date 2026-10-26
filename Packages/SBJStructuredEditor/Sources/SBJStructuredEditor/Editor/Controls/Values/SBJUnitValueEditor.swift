import SBJDataDefinition
import SBJUIVocabulary

/// Presentation mode derived from the SBJUnitValue unitMutable constraint.
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
        editor: SBJUnitValueEditorMode,
        unitSystem: MeasurementSystem?
    ) -> AnyView
}

extension UnitValue: _SBJUnitValueEditorValue {
    @MainActor
    static func _sbjMakeUnitValueEditor(
        label: String,
        binding: SBJAnyBinding,
        labelIsUnknown: Bool,
        editor: SBJUnitValueEditorMode,
        unitSystem: MeasurementSystem?
    ) -> AnyView {
        AnyView(
            SBJUnitValueEditor(
                label: label,
                value: binding.binding(as: Self.self),
                labelIsUnknown: labelIsUnknown,
                editor: editor,
                unitSystem: unitSystem
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
    let unitSystem: MeasurementSystem?

    var body: some View {
        SBJEditorLabeledField(label: label, labelIsUnknown: labelIsUnknown) {
            UnitValueControl(
                value: $value,
                units: Array(Unit.allCases).filter { unit in
                    unitSystem == nil || unit.measurementSystem == .universal || unit.measurementSystem == unitSystem
                },
                accessibilityLabel: label,
                unitEditable: editor == .editable
            )
        }
    }
}
#endif
