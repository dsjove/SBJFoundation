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

extension MixedUnitValue: _SBJUnitValueEditorValue {
    @MainActor
    static func _sbjMakeUnitValueEditor(
        label: String,
        binding: SBJAnyBinding,
        labelIsUnknown: Bool,
        editor: SBJUnitValueEditorMode,
        unitSystem: MeasurementSystem?
    ) -> AnyView {
        AnyView(
            SBJMixedUnitValueEditor(
                label: label,
                value: binding.binding(as: Self.self),
                labelIsUnknown: labelIsUnknown,
                editor: editor,
                unitSystem: unitSystem
            )
        )
    }
}

extension MixedUnitValue: SBJTypedEditorValue {}

extension PairedUnitValue: _SBJUnitValueEditorValue {
    @MainActor
    static func _sbjMakeUnitValueEditor(
        label: String, binding: SBJAnyBinding, labelIsUnknown: Bool,
        editor: SBJUnitValueEditorMode, unitSystem: MeasurementSystem?
    ) -> AnyView {
        AnyView(SBJPairedUnitValueEditor(label: label,
            value: binding.binding(as: Self.self), labelIsUnknown: labelIsUnknown,
            editor: editor, unitSystem: unitSystem))
    }
}

extension PairedUnitValue: SBJTypedEditorValue {}

/// Returns the unit choices available under a declared measurement system.
/// This affects editor choices only; it does not modify or validate stored values.
private func sbjAvailableUnits<Unit: UnitType>(for system: MeasurementSystem?) -> [Unit] {
    Array(Unit.allCases).filter { unit in
        system == nil || unit.measurementSystem == .universal || unit.measurementSystem == system
    }
}

struct SBJPairedUnitValueEditor<Unit: UnitType>: View {
    let label: String
    @Binding var value: PairedUnitValue<Unit>
    let labelIsUnknown: Bool
    let editor: SBJUnitValueEditorMode
    let unitSystem: MeasurementSystem?

    var body: some View {
        SBJEditorLabeledField(label: label, labelIsUnknown: labelIsUnknown) {
            HStack(spacing: 8) {
                TextField("", value: $value.first, format: .number)
                    .sbjSingleLineField()
                    .frame(width: 92)
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel("\(label) first")
                if value.second != nil {
                    Text("–")
                        .foregroundStyle(.secondary)
                    TextField("", value: Binding<Double>(
                        get: { value.second ?? 0 },
                        set: { value.second = $0 }), format: .number)
                        .sbjSingleLineField()
                        .frame(width: 92)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("\(label) second")
                }
                if editor == .editable {
                    SBJSelectionMenu(
                        selection: Binding<Int?>(
                            get: { availableUnits.firstIndex(of: value.unit) },
                            set: { index in
                                guard let index, availableUnits.indices.contains(index) else { return }
                                value = value.converted(to: availableUnits[index])
                            }),
                        choices: availableUnits.enumerated().map {
                            SBJMenuChoice(id: $0.offset, title: $0.element.presentedValue)
                        }, currentTitle: value.unit.symbol,
                        invalidSelection: !availableUnits.contains(value.unit))
                } else {
                    Text(value.unit.symbol).foregroundStyle(.secondary)
                }
                Button {
                    value.second = value.second == nil ? 0 : nil
                } label: {
                    Image(systemName: value.second == nil ? "plus.circle" : "minus.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(value.second == nil ? "Add second \(label)" : "Remove second \(label)")
            }.fixedSize(horizontal: true, vertical: false)
        }
    }

    private var availableUnits: [Unit] {
        sbjAvailableUnits(for: unitSystem)
    }
}



struct SBJMixedUnitValueEditor<Unit: UnitType>: View {
    let label: String
    @Binding var value: MixedUnitValue<Unit>
    let labelIsUnknown: Bool
    let editor: SBJUnitValueEditorMode
    let unitSystem: MeasurementSystem?

    var body: some View {
        SBJEditorLabeledField(label: label, labelIsUnknown: labelIsUnknown) {
            HStack(spacing: 8) {
                UnitValueControl(
                    value: $value.major,
                    units: availableUnits,
                    accessibilityLabel: "\(label) major",
                    unitEditable: editor == .editable
                )
                UnitValueControl(
                    value: $value.minor,
                    units: availableUnits,
                    accessibilityLabel: "\(label) minor",
                    unitEditable: editor == .editable
                )
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var availableUnits: [Unit] {
        sbjAvailableUnits(for: unitSystem)
    }
}


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
                units: sbjAvailableUnits(for: unitSystem),
                accessibilityLabel: label,
                unitEditable: editor == .editable
            )
        }
    }
}
#endif
