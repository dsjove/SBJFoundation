#if !os(tvOS) && !os(watchOS)
import Foundation
import SBJDataDefinition
import SwiftUI

struct SBJArrayEditor<Element: Codable>: View {
    let label: String
    @Binding var value: [Element]
    let originalValue: [Element]?
    let registry: SBJEditorRegistry
    let textStyle: SBJStringStyle?
    let integerRange: ClosedRange<Int>?
    let numberRange: ClosedRange<Double>?
    let reorderable: Bool
    let itemTitleKey: String?
    let itemIdentifierKey: String?
    let itemActions: SBJEditorItemActions?
    let focusRequest: SBJEditorFocusRequest?
    let context: SBJEditTraversalContext
    @Environment(SBJEditorPresentationModel.self) private var presentationModel

    private var disclosureBinding: Binding<Bool> {
        presentationModel.disclosureBinding(for: context)
    }

    var body: some View {
        let canAdd = registry.createArrayElement(Element.self, existing: value) != nil
        return VStack(alignment: .leading, spacing: 6) {
            SBJEditorDisclosureHeader(
                "\(label) (\(value.count))",
                context: context,
                isExpanded: disclosureBinding,
                leadingActions: AnyView(
                    HStack(spacing: 6) {
                        if let itemActions {
                            itemActions.leadingView
                        }
                        SBJAddButton(
                            label,
                            accessibilityHint: "Adds a new item and moves focus into it"
                        ) {
                            if let newValue = registry.createArrayElement(Element.self, existing: value) {
                                value.append(newValue)
                                presentationModel.open(context.itemIdentifier)
                            }
                        }
                        .disabled(!canAdd)
                    }
                ),
                trailingActions: AnyView(
                    HStack(spacing: 6) {
                        if let itemActions {
                            itemActions.trailingView
                        }
                    }
                )
            )
        }
    }
}
#endif
