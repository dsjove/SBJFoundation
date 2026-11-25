import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJCaseIterableEditor<Value>: View {
    let label: String
    @Binding var value: Value
    let options: [Value]
    let labelIsUnknown: Bool

    private var selectedIndex: Int? {
        if let optionMatches { return options.firstIndex { optionMatches($0, value) } }
        guard let current = value as? AnyHashable else { return nil }
        return options.firstIndex { ($0 as? AnyHashable) == current }
    }

    var rowStatus: SBJEditorRowStatus = .init()
    var optionTitle: ((Value) -> String)? = nil
    var optionMatches: ((Value, Value) -> Bool)? = nil

    private func title(_ value: Value) -> String {
        optionTitle?(value) ?? sbjCaseIterablePresentation(value)
    }

    var body: some View {
        SBJEditorLabeledField(label: label, labelIsUnknown: labelIsUnknown) {
            SBJSelectionMenu(
                selection: Binding<Int?>(
                    get: { selectedIndex },
                    set: { index in
                        guard let index, options.indices.contains(index) else { return }
                        value = options[index]
                    }
                ),
                choices: options.enumerated().map {
                    SBJMenuChoice(id: $0.offset, title: title($0.element))
                },
                currentTitle: title(value),
                invalidSelection: selectedIndex == nil
            )
            .sbjEditorAccessibleControl(label: label, status: rowStatus)
        }
    }
}

private func sbjCaseIterablePresentation<Value>(_ value: Value) -> String {
    if let presentable = value as? any SBJTextPresentable {
        return presentable.presentedValue
    }
    return String(describing: value).uncamelCased
}

func caseIterableOptions<Value>(for type: Value.Type) -> [Value]? {
    guard type is any Hashable.Type,
          let caseIterable = type as? any CaseIterable.Type else { return nil }
    let values = caseIterable.allCases.compactMap { $0 as? Value }
    return values.isEmpty ? nil : values
}
#endif
