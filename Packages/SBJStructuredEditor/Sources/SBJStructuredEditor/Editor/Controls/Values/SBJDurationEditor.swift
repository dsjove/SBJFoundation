import SBJDataDefinition
import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Edit TimeInterval as a compact, colon-separated duration in configured units.
/// Invalid intermediate text stays visible until valid; the model is unchanged.
struct SBJDurationEditor: View {
    let label: String
    @Binding var value: Double
    let units: ClosedRange<DurationUnit>
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool
    var rowStatus: SBJEditorRowStatus = .init()
    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var valid: Bool { text.timeInterval(units: units) != nil }
    private var unitsLabel: String {
        func abbreviation(_ unit: DurationUnit) -> String {
            switch unit {
            case .milliseconds: "ms"
            case .second: "sec"
            case .minute: "min"
            case .hour: "hr"
            case .day: "day"
            }
        }
        return "\(label) (\(abbreviation(units.lowerBound))...\(abbreviation(units.upperBound)))"
    }

    var body: some View {
        SBJEditorLabeledField(label: unitsLabel, labelIsUnknown: labelIsUnknown) {
            TextField("", text: $text)
                .sbjSingleLineField(isFocused: $isFocused)
                .sbjEditorAccessibleControl(label: unitsLabel, status: rowStatus)
                .invalidDecoration(!text.isEmpty && !valid)
                .onSubmit(commit)
                .onChange(of: isFocused) { _, focused in
                    if !focused { commit() }
                }
#if os(iOS)
                .keyboardType(.numbersAndPunctuation)
#endif
        }
        .onAppear {
            text = value.timestampString(units: units)
            focusRequest?.claim($isFocused)
        }
        .onChange(of: value) { _, newValue in
            if !isFocused { text = newValue.timestampString(units: units) }
        }
    }

    private func commit() {
        guard let interval = text.timeInterval(units: units) else { return }
        value = interval
        text = interval.timestampString(units: units)
    }
}
#endif
