#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJCaseIterableEditor<Value>: View {
    let label: String
    @Binding var value: Value
    let options: [Value]
    let labelIsUnknown: Bool

    private var selectedIndex: Int {
        guard let current = value as? AnyHashable else { return 0 }
        return options.firstIndex { ($0 as? AnyHashable) == current } ?? 0
    }

    var body: some View {
        SBJEditorLabeledField(label: label, labelIsUnknown: labelIsUnknown) {
            Menu {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Button(sbjCaseIterablePresentation(option)) {
                        value = options[index]
                    }
                }
            } label: {
                SBJCompactMenuLabel(text: sbjCaseIterablePresentation(value))
            }
            .controlSize(.mini)
            .fixedSize()
            .sbjActiveControl(horizontalPadding: 4, verticalPadding: 0)
            .sbjEditorAccessibleControl(label: label)
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
