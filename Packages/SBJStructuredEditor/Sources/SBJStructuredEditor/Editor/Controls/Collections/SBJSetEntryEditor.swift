import SBJUIVocabulary
import SBJUnits
#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJSetEntryEditor<Element: Codable & Hashable>: View {
    struct Configuration {
        var textStyle: SBJStringStyle? = nil
        var integerRange: ClosedRange<Int>? = nil
        var numberRange: ClosedRange<Double>? = nil
        var focusRequest: SBJEditorFocusRequest? = nil
    }

    let element: Element
    let originalElement: Element?
    let title: String
    let registry: SBJEditorRegistry
    let configuration: Configuration
    let context: SBJEditTraversalContext
    let replace: (Element, Element) -> Bool
    let remove: () -> Void
    @State private var draft: Element
    @State private var collision = false

    init(
        element: Element,
        originalElement: Element? = nil,
        title: String,
        registry: SBJEditorRegistry,
        context: SBJEditTraversalContext,
        configuration: Configuration = .init(),
        replace: @escaping (Element, Element) -> Bool,
        remove: @escaping () -> Void
    ) {
        self.element = element
        self.originalElement = originalElement
        self.title = title
        self.registry = registry
        self.configuration = configuration
        self.context = context
        self.replace = replace
        self.remove = remove
        _draft = State(initialValue: element)
    }

    private var isChanged: Bool {
        guard let originalElement else { return true }
        return !SBJStructuralCompare.equals(draft, originalElement)
    }

    private var isInvalid: Bool {
        SBJInvariantCheck.validationError(
            draft,
            at: SBJValidationKeyPath(\Element.self)
        ) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                SBJRemoveButton(accessibilityLabel: "Remove \(title)", action: remove)

                SBJValueEditor.makeView(
                    label: title,
                    value: $draft,
                    originalValue: originalElement.map { SBJEditorOriginalValue($0) },
                    registry: registry,
                    textStyle: configuration.textStyle,
                    integerRange: configuration.integerRange,
                    numberRange: configuration.numberRange,
                    focusRequest: configuration.focusRequest,
                    context: context.withBranch(context.branch.withStatus(
                        .init(isChanged: isChanged,
                              hasContent: (draft as? any HasContentCheckable)?.hasContent,
                              isInvalid: isInvalid)
                    ))
                )

                if draft != element {
                    SBJApplyButton(accessibilityLabel: "Apply \(title)") {
                        collision = !replace(element, draft)
                    }
                }
            }
            if collision {
                Text("That value is already in the set.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: element) { _, newValue in
            draft = newValue
            collision = false
        }
        .onChange(of: draft) { _, _ in collision = false }
    }
}
#endif
