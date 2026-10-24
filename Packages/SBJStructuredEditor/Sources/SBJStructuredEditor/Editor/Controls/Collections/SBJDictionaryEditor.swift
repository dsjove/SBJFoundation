import SBJUIVocabulary
import SBJUnits
#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJDictionaryEditor<Key: Codable & Hashable, Value: Codable>: View {
    let label: String
    @Binding var value: [Key: Value]
    let originalValue: [Key: Value]?
    let registry: SBJEditorRegistry
    let textStyle: SBJStringStyle?
    let integerRange: ClosedRange<Int>?
    let numberRange: ClosedRange<Double>?
    let itemActions: SBJEditorItemActions?
    let focusRequest: SBJEditorFocusRequest?
    let context: SBJEditTraversalContext
    @Environment(SBJEditorPresentationModel.self) private var presentationModel

    private var disclosureBinding: Binding<Bool> {
        presentationModel.disclosureBinding(for: context)
    }

    private var addCandidate: (Key, Value)? {
        guard let key = registry.create(Key.self),
              !value.keys.contains(key),
              let entryValue = registry.create(Value.self) else { return nil }
        return (key, entryValue)
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
                            guard let (key, entryValue) = addCandidate else { return }
                            value.updateValue(entryValue, forKey: key)
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
