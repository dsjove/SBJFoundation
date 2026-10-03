#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJColorEditor: View {
    let label: String
    @Binding var value: CodableColor
    let supportsAlpha: Bool
    let labelIsUnknown: Bool
    @Environment(\.self) private var environment
    @Environment(\.locale) private var locale

    private var colorBinding: Binding<Color> {
        Binding(
            get: { value.swiftUIColor },
            set: { newColor in
                value = CodableColor(color: newColor.resolve(in: environment))
            }
        )
    }

    var body: some View {
        SBJEditorLabeledField(label: label, labelIsUnknown: labelIsUnknown) {
            ColorPicker("", selection: colorBinding, supportsOpacity: supportsAlpha)
                .labelsHidden()
                .fixedSize()
                .sbjEditorAccessibleControl(label: label)
        }
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        let red = Int((value.red * 255).rounded()).formatted(.number.locale(locale))
        let green = Int((value.green * 255).rounded()).formatted(.number.locale(locale))
        let blue = Int((value.blue * 255).rounded()).formatted(.number.locale(locale))
        let components = "Red \(red), green \(green), blue \(blue)"
        guard supportsAlpha else { return components }

        // Percent.FormatStyle expects the fractional value (0...1), so the
        // locale supplies both the appropriate digits and percent punctuation.
        let opacity = value.opacity.formatted(.percent.precision(.fractionLength(0)).locale(locale))
        return "\(components), opacity \(opacity)"
    }
}
#endif
