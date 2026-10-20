import SwiftUI
import SBJDataDefinition
import SBJLocalization

@MainActor
public struct SBJAddButton: View {
    private let visibleLabel: String?
    private let accessibilityLabel: String
    private let accessibilityHint: String?
    private let action: () -> Void

    /// TODO(Localization): Do not localize `noun` and "Add" independently. The
    /// eventual SBJ text-resource migration must represent the complete action
    /// phrase so translators can reorder/inflect it appropriately. See
    /// Documentation/LOCALIZATION_AND_PRESENTATION_RESOURCES.md.
    public init(
        _ noun: String,
        labeled: Bool = false,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.visibleLabel = labeled ? noun : nil
        self.accessibilityLabel = "Add \(noun)"
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    public init(
        accessibilityLabel: String = "Add",
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.visibleLabel = nil
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    public var body: some View {
        if let visibleLabel {
            Button(action: action) {
                Label(visibleLabel, symbol: SBJSymbology.add)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(accessibilityLabel)
            .applyIf(accessibilityHint) { view, hint in
                view.accessibilityHint(hint)
            }
        } else {
            SBJSymbolButton(
                SBJSymbology.add,
                accessibilityLabel: accessibilityLabel,
                accessibilityHint: accessibilityHint,
                action: action
            )
        }
    }
}
