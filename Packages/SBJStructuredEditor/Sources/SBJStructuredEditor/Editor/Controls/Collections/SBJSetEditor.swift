import SBJUIVocabulary
import SBJUnits
#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJSetEditor<Element: Codable & Hashable>: View {
    let label: String
    @Binding var value: Set<Element>
    let originalValue: Set<Element>?
    let registry: SBJEditorRegistry
    let textStyle: SBJStringStyle?
    let integerRange: ClosedRange<Int>?
    let numberRange: ClosedRange<Double>?
    let itemTitleKey: String?
    let itemActions: SBJEditorItemActions?
    let focusRequest: SBJEditorFocusRequest?
    let context: SBJEditTraversalContext
    @Environment(SBJEditorPresentationModel.self) private var presentationModel

    private var disclosureBinding: Binding<Bool> {
        presentationModel.disclosureBinding(for: context)
    }

    private var addCandidate: Element? {
        guard let candidate = registry.create(Element.self), !value.contains(candidate) else { return nil }
        return candidate
    }

    var body: some View {
        let canAdd = addCandidate != nil
        return VStack(alignment: .leading, spacing: 6) {
            SBJEditorDisclosureHeader(
                "\(label) (\(value.count))",
                context: context,
                isExpanded: disclosureBinding,
                leadingActions: AnyView(
                    HStack(spacing: 6) {
                        SBJAddButton(label) {
                            guard let candidate = addCandidate else { return }
                            value.insert(candidate)
                            presentationModel.open(context.itemIdentifier)
                        }
                        .disabled(!canAdd)
                    }
                ),
                trailingActions: AnyView(
                    HStack(spacing: 6) {
                        if let itemActions { itemActions.trailingView }
                    }
                )
            )
        }
    }
}
#endif
