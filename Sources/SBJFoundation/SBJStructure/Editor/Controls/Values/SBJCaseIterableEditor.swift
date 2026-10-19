#if !os(tvOS) && !os(watchOS)
import Foundation
import SBJDataDefinition
import SwiftUI
import SBJLocalization

struct SBJCaseIterableEditor<Value>: View {
    let label: String
    @Binding var value: Value
    let options: [Value]
    let labelIsUnknown: Bool

    private var selectedIndex: Int? {
        guard let current = value as? AnyHashable else { return nil }
        return options.firstIndex { ($0 as? AnyHashable) == current }
    }

    var rowStatus: SBJEditorRowStatus = .init()

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
                    SBJMenuChoice(id: $0.offset, title: sbjCaseIterablePresentation($0.element))
                },
                currentTitle: sbjCaseIterablePresentation(value),
                invalidSelection: selectedIndex == nil
            )
            .sbjEditorAccessibleControl(label: label, status: rowStatus)
        }
    }
}

private func sbjCaseIterablePresentation<Value>(_ value: Value) -> String {
    if let presentable = value as? any StringPresentable {
        return presentable.description
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
