import SwiftUI
import SBJDataDefinition

/// Compact reusable control for a numeric value paired with a unit.
///
/// Choosing another unit preserves the represented physical quantity by
/// converting the numeric value. Reinterpreting the same number in a different
/// unit is intentionally not the behavior of this control.
@MainActor
public struct UnitValueControl<Unit: UnitType & StringPresentable>: View {
    @Binding private var value: UnitValue<Unit>
    private let units: [Unit]
    private let accessibilityLabel: String?
    private let propertyInfo: SBJPropertyInfo?
    private let unitEditable: Bool
    @FocusState private var isFocused: Bool

    public init(
        value: Binding<UnitValue<Unit>>,
        units: [Unit] = Array(Unit.allCases),
        accessibilityLabel: String? = nil,
        propertyInfo: SBJPropertyInfo? = nil,
        unitEditable: Bool = false
    ) {
        _value = value
        self.units = units
        self.accessibilityLabel = accessibilityLabel
        self.propertyInfo = propertyInfo
        self.unitEditable = unitEditable
    }

    public var body: some View {
        HStack(spacing: 6) {
            TextField("", value: $value.value, format: .number)
                .oneLiner(isFocused: $isFocused)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 72, idealWidth: 96, maxWidth: 132)
#if os(iOS)
                .keyboardType(.decimalPad)
#endif
                .accessibilityLabel(accessibilityLabel ?? propertyInfo?.accessibilityLabel ?? UnitValue<Unit>.valueInfo.accessibilityLabel ?? "Value")

            unitControl
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var unitControl: some View {
        if !unitEditable {
            Text(value.unit.symbol)
                .foregroundStyle(.secondary)
                .fixedSize()
                .accessibilityLabel(UnitValue<Unit>.unitInfo.accessibilityLabel ?? "Unit")
                .accessibilityValue(value.unit.description)
        } else {
            SBJSelectionMenu(
                selection: Binding<Int?>(
                    get: { units.firstIndex(of: value.unit) },
                    set: { index in
                        guard let index, units.indices.contains(index) else { return }
                        value = value.converted(to: units[index])
                    }
                ),
                choices: units.enumerated().map {
                    SBJMenuChoice(id: $0.offset, title: $0.element.description)
                },
                currentTitle: value.unit.symbol,
                invalidSelection: !units.contains(value.unit)
            )
            .accessibilityLabel(UnitValue<Unit>.unitInfo.accessibilityLabel ?? "Unit")
            .accessibilityValue(value.unit.description)
        }
    }
}
