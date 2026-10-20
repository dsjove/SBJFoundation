import SwiftUI
import SBJDataDefinition
import SBJHelp
import SBJUIVocabulary

@MainActor
public struct UnitConversionView<Unit: UnitType & StringPresentable>: View {
    @Bindable private var model: UnitConversionModel<Unit>
    private let units: [Unit]
    private let editingPolicy: UnitEditingPolicy<Unit>?

    public init(
        model: UnitConversionModel<Unit>,
        units: [Unit] = Array(Unit.allCases),
        editingPolicy: UnitEditingPolicy<Unit>? = nil
    ) {
        self.model = model
        self.units = units
        self.editingPolicy = editingPolicy
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                UnitValueControl(
                    value: $model.source,
                    units: units,
                    propertyInfo: UnitConversionModel<Unit>.sourceInfo
                )

#if !os(tvOS) && !os(watchOS)
                if let editingPolicy {
                    Stepper(
                        onIncrement: { model.step(using: editingPolicy, increasing: true) },
                        onDecrement: { model.step(using: editingPolicy, increasing: false) }
                    ) { EmptyView() }
                    .labelsHidden()
                }
#endif

                SBJSymbolButton(
                    SBJUnitSymbology.resetValue,
                    propertyInfo: UnitConversionModel<Unit>.resetPropertyInfo
                ) {
                    model.reset()
                }
            }

            HStack(spacing: 10) {
                Text(model.source.unit.description)
                    .foregroundStyle(.secondary)

                SBJSymbolButton(
                    SBJUnitSymbology.swapUnits,
                    propertyInfo: UnitConversionModel<Unit>.swapPropertyInfo
                ) {
                    model.swap()
                }

                SBJSelectionMenu(
                    selection: Binding<Int?>(
                        get: { units.firstIndex(of: model.destinationUnit) },
                        set: { index in
                            guard let index, units.indices.contains(index) else { return }
                            model.destinationUnit = units[index]
                        }
                    ),
                    choices: units.enumerated().map {
                        SBJMenuChoice(id: $0.offset, title: $0.element.description)
                    },
                    currentTitle: model.destinationUnit.symbol,
                    invalidSelection: !units.contains(model.destinationUnit)
                )
                .accessibilityLabel(UnitConversionModel<Unit>.destinationUnitInfo.accessibilityLabel ?? "To unit")
                .accessibilityValue(model.destinationUnit.description)
            }

            LabeledContent("Result") {
                HStack(spacing: 4) {
                    Text(model.result.value.formatted(.number))
                        .contentTransition(.numericText())
                    Text(model.result.unit.symbol)
                        .foregroundStyle(.secondary)
                }
            }
        }
#if !os(watchOS)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                SBJHelpLink(
                    asset: SBJUnitSymbology.unitConversionHelp,
                    configuration: SBJUnitSymbology.helpConfiguration
                )
            }
        }
#endif
    }
}

/// Ready-made multi-dimension conversion tool suitable for an app utility
/// screen. Applications can constrain both the visible categories and the
/// units within each category without rebuilding the conversion UI.
@MainActor
public struct ConversionView: View {
    @State private var category: UnitCategory
    @State private var length = UnitConversionModel(
        source: UnitValue<LengthUnit>(1, unit: .inch),
        destinationUnit: .centimeter
    )
    @State private var mass = UnitConversionModel(
        source: UnitValue<MassUnit>(1, unit: .ounce),
        destinationUnit: .gram
    )
    @State private var volume = UnitConversionModel(
        source: UnitValue<VolumeUnit>(1, unit: .tablespoon),
        destinationUnit: .cup
    )
    @State private var duration = UnitConversionModel(
        source: UnitValue<DurationUnit>(1, unit: .hour),
        destinationUnit: .minute
    )

    private let categories: [UnitCategory]
    private let lengthUnits: [LengthUnit]
    private let massUnits: [MassUnit]
    private let volumeUnits: [VolumeUnit]
    private let durationUnits: [DurationUnit]
    private let lengthEditingPolicy: UnitEditingPolicy<LengthUnit>?
    private let massEditingPolicy: UnitEditingPolicy<MassUnit>?
    private let volumeEditingPolicy: UnitEditingPolicy<VolumeUnit>?
    private let durationEditingPolicy: UnitEditingPolicy<DurationUnit>?

    public init(
        category: UnitCategory = .volume,
        categoryFilter: (UnitCategory) -> Bool = { _ in true },
        lengthUnitFilter: (LengthUnit) -> Bool = { _ in true },
        massUnitFilter: (MassUnit) -> Bool = { _ in true },
        volumeUnitFilter: (VolumeUnit) -> Bool = { _ in true },
        durationUnitFilter: (DurationUnit) -> Bool = { _ in true },
        lengthEditingPolicy: UnitEditingPolicy<LengthUnit>? = nil,
        massEditingPolicy: UnitEditingPolicy<MassUnit>? = nil,
        volumeEditingPolicy: UnitEditingPolicy<VolumeUnit>? = nil,
        durationEditingPolicy: UnitEditingPolicy<DurationUnit>? = nil
    ) {
        let categories = UnitCategory.allCases.filter(categoryFilter)
        precondition(!categories.isEmpty, "ConversionView requires at least one category.")
        _category = State(initialValue: categories.contains(category) ? category : categories[0])
        self.categories = categories
        self.lengthUnits = LengthUnit.allCases.filter(lengthUnitFilter)
        self.massUnits = MassUnit.allCases.filter(massUnitFilter)
        self.volumeUnits = VolumeUnit.allCases.filter(volumeUnitFilter)
        self.durationUnits = DurationUnit.allCases.filter(durationUnitFilter)
        self.lengthEditingPolicy = lengthEditingPolicy
        self.massEditingPolicy = massEditingPolicy
        self.volumeEditingPolicy = volumeEditingPolicy
        self.durationEditingPolicy = durationEditingPolicy
    }

    public var body: some View {
        VStack(spacing: 16) {
            if categories.count > 1 {
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { category in
                        Text(categoryTitle(category)).tag(category)
                    }
                }
#if !os(watchOS)
                .pickerStyle(.segmented)
#endif
            }

            switch category {
            case .length:
                UnitConversionView(model: length, units: lengthUnits, editingPolicy: lengthEditingPolicy)
            case .mass:
                UnitConversionView(model: mass, units: massUnits, editingPolicy: massEditingPolicy)
            case .volume:
                UnitConversionView(model: volume, units: volumeUnits, editingPolicy: volumeEditingPolicy)
            case .duration:
                UnitConversionView(model: duration, units: durationUnits, editingPolicy: durationEditingPolicy)
            }
        }
    }

    private func categoryTitle(_ category: UnitCategory) -> String {
        switch category {
        case .length: "Length"
        case .mass: "Weight"
        case .duration: "Time"
        case .volume: "Volume"
        }
    }
}
