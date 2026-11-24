import SwiftUI

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
        self.accessibilityLabel = "\(SBJCommonNomenclature.add.title) \(noun)"
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    public init(
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.visibleLabel = nil
        self.accessibilityLabel = accessibilityLabel ?? SBJCommonNomenclature.add.title
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    public var body: some View {
        if let visibleLabel {
            Button(action: action) {
                Label(visibleLabel, symbol: SBJCommonNomenclature.add.symbol!)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(accessibilityLabel)
            .applyIf(accessibilityHint) { view, hint in
                view.accessibilityHint(hint)
            }
        } else {
            SBJSymbolButton(
                SBJCommonNomenclature.add.symbol!,
                accessibilityLabel: accessibilityLabel,
                accessibilityHint: accessibilityHint,
                action: action
            )
        }
    }
}
