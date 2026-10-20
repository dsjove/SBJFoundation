import SwiftUI
import SBJDataDefinition
import SBJUIVocabulary

/// A checkbox presentation for `Toggle` that keeps the normal Toggle binding contract while
/// presenting an explicit checked/unchecked semantic image.
public struct SBJCheckboxToggleStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                Spacer()
                Image(symbol: configuration.isOn ? SBJSymbology.checked : SBJSymbology.unchecked)
                    .foregroundStyle(configuration.isOn ? SBJUIAppearance.activeControlColor : SBJUIAppearance.inactiveControlColor)
                    .imageScale(.large)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "Checked" : "Unchecked")
    }
}

public extension ToggleStyle where Self == SBJCheckboxToggleStyle {
    static var sbjCheckbox: SBJCheckboxToggleStyle { SBJCheckboxToggleStyle() }
}
