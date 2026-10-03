#if !os(tvOS) && !os(watchOS)
import Foundation
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
    @State private var disclosureState = SBJEditorDisclosureState()
    @State private var focusIndex: Int?
    @State private var pendingFocus: SBJEditorFocusRequest?
    @Environment(\.sbjEditorSearchCriteria) private var searchCriteria
    @Environment(\.sbjEditorNavigationTarget) private var navigationTarget
    @Environment(\.sbjEditorHasContent) private var hasContent

    /// Expansion has independent user, search, and navigation sources. The user's disclosure choice is
    /// persistent editor state; filtering/search may temporarily require this
    /// node to be open. Search never mutates the user's choice.
    private var searchIsExpanded: Bool {
        searchCriteria.forcesExpansion(hasContent: hasContent)
    }

    private var navigationIsExpanded: Bool {
        navigationTarget?.contains(context.navigationPath) == true
    }

    private func commitNavigationExpansionIfNeeded() {
        disclosureState.commitNavigationExpansion(
            target: navigationTarget,
            path: context.navigationPath
        )
    }

    private var resolvedIsExpanded: Bool {
        disclosureState.resolved(
            searchIsExpanded: searchIsExpanded,
            navigationIsExpanded: navigationIsExpanded
        )
    }

    private var disclosureBinding: Binding<Bool> {
        Binding(
            get: { resolvedIsExpanded },
            set: { disclosureState.setUserExpansion($0, searchIsExpanded: searchIsExpanded) }
        )
    }

    private var isDisplayingFilteredSubset: Bool {
        SBJArrayEditorPresentation.isDisplayingFilteredSubset(criteria: searchCriteria)
    }

    private var displayIndices: [Int] {
        Array(value.indices).filter { index in
            let navigationTitle = SBJCollectionItemIdentification.arrayTitle(
                for: value[index],
                index: index,
                itemTitleKey: itemTitleKey
            )
            if navigationTarget?.contains(context.navigationPath + [navigationTitle]) == true {
                return true
            }
            return searchCriteria.includes(
                isChanged: itemHasChanged(at: index),
                containsEmptyContent: SBJContentCheck.containsEmptyContent(
                    value[index],
                    treatingAsLeaf: { registry.hasCustomEditor($0) }
                ),
                matchesSearch: { query in
                    if sbjPredicated(label, search: query) { return true }
                    let title = itemTitle(for: value[index], index: index).text
                    return sbjPredicated(label: title, value: value[index], search: query)
                }
            )
        }
    }

    private var displayItems: [SBJEditorSnapshotItem<Int>] {
        displayIndices.map { index in
            let stable = SBJCollectionItemIdentification.stableIdentifier(
                for: value[index],
                itemIdentifierKey: itemIdentifierKey
            ) ?? "slot:\(index)"
            return SBJEditorSnapshotItem(
                itemIdentifier: context.itemIdentifier.appending("item:\(stable)"),
                indexPath: context.indexPath.appending("index:\(index)"),
                content: index
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SBJEditorDisclosureHeader(
                "\(label) (\(value.count))",
                treeLevel: context.treeLevel,
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
                                focusIndex = value.index(before: value.endIndex)
                                pendingFocus = SBJEditorFocusRequest()
                                disclosureState.userIsExpanded = true
                            }
                        }
                        .disabled(registry.createArrayElement(Element.self, existing: value) == nil)
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

            if resolvedIsExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if displayIndices.isEmpty {
                        SBJEditorEmptyDisclosureContent(
                            message: value.isEmpty
                                ? "No entries. Use + to add one."
                                : "No entries match the current filters."
                        )
                    }

                    ForEach(displayItems) { item in
                        let index = item.content
                        let navigationTitle = SBJCollectionItemIdentification.arrayTitle(
                            for: value[index],
                            index: index,
                            itemTitleKey: itemTitleKey
                        )
                        let itemContext = SBJEditTraversalContext(
                            treeLevel: context.treeLevel + 1,
                            itemIdentifier: item.itemIdentifier,
                            indexPath: item.indexPath,
                            navigationPath: context.navigationPath + [navigationTitle]
                        )
                        let itemLabel = itemTitle(for: value[index], index: index)
                        let itemSearchCriteria = searchCriteria.descendingPastMatchedLabels(label, itemLabel.text)
                        let itemInvalid = SBJInvariantCheck.validationError(
                            value[index],
                            at: SBJValidationKeyPath(\Element.self)
                        ) != nil
                        let currentValue = value[index]
                        SBJValueEditor.makeView(
                            label: itemLabel.text,
                            value: Binding(
                                // SwiftUI may evaluate a removed row once more
                                // before destroying its subtree. Keep the value
                                // captured for this row as a safe final read and
                                // ignore writes once its index no longer exists.
                                get: {
                                    guard value.indices.contains(index) else { return currentValue }
                                    return value[index]
                                },
                                set: { newValue in
                                    guard value.indices.contains(index) else { return }
                                    value[index] = newValue
                                }
                            ),
                            originalValue: originalElement(at: index).map { SBJEditorOriginalValue($0) },
                            registry: registry,
                            textStyle: textStyle,
                            integerRange: integerRange,
                            numberRange: numberRange,
                            promotedTitlePropertyName: itemTitleKey,
                            promotedTitlePrefix: "\(SBJArrayEditorPresentation.itemNumber(for: index)))",
                            itemActions: actions(for: index),
                            focusRequest: index == focusIndex ? pendingFocus : focusRequest,
                            labelIsUnknown: itemLabel.isUnknown,
                            context: itemContext
                        )
                        .environment(\.sbjEditorSearchCriteria, itemSearchCriteria)
                        .environment(\.sbjEditorIsChanged, itemHasChanged(at: index))
                        .environment(\.sbjEditorHasContent, (value[index] as? any HasContentCheckable)?.hasContent)
                        .environment(\.sbjEditorIsInvalid, itemInvalid)
                        .sbjEditorNavigationAnchor(for: itemContext.navigationPath)
                        .accessibilityIdentifier(item.itemIdentifier.description)
                    }
                }
                .frame(maxWidth: .infinity)

                SBJEditorLevelExitDivider()
            }
        }
        .onAppear {
            commitNavigationExpansionIfNeeded()
        }
        .onChange(of: navigationTarget) { _, _ in
            commitNavigationExpansionIfNeeded()
        }
    }

    private func originalElement(at index: Int) -> Element? {
        guard value.indices.contains(index), let originalValue else { return nil }

        // When the collection declares a structural Item Identifier, position is
        // presentation state rather than identity. Match the current item to its
        // original by identifier so reordering/insertion/deletion cannot make a
        // child field compare against the wrong original element.
        if itemIdentifierKey != nil,
           let currentIdentifier = SBJCollectionItemIdentification.stableIdentifier(
               for: value[index],
               itemIdentifierKey: itemIdentifierKey
           ) {
            return originalValue.first { original in
                SBJCollectionItemIdentification.stableIdentifier(
                    for: original,
                    itemIdentifierKey: itemIdentifierKey
                ) == currentIdentifier
            }
        }

        guard originalValue.indices.contains(index) else { return nil }
        return originalValue[index]
    }

    private func itemHasChanged(at index: Int) -> Bool {
        guard value.indices.contains(index) else { return false }
        guard let original = originalElement(at: index) else { return true }
        return !SBJStructuralCompare.equals(value[index], original)
    }

    private func itemTitle(for element: Element, index: Int) -> (text: String, isUnknown: Bool) {
        let prefix = "\(SBJArrayEditorPresentation.itemNumber(for: index))) "
        guard let title = SBJCollectionItemIdentification.configuredTitle(
            for: element,
            itemTitleKey: itemTitleKey
        ) else {
            return (prefix + label, true)
        }
        return (prefix + title, false)
    }

    private func actions(for index: Int) -> SBJEditorItemActions {
        SBJEditorItemActions(
            remove: {
                guard value.indices.contains(index) else { return }
                value.remove(at: index)
                if focusIndex == index {
                    focusIndex = nil
                    pendingFocus = nil
                } else if let focusIndex, focusIndex > index {
                    self.focusIndex = focusIndex - 1
                }
            },
            moveUp: reorderable && !isDisplayingFilteredSubset && index > value.startIndex ? {
                guard value.indices.contains(index), value.indices.contains(index - 1) else { return }
                value.swapAt(index, index - 1)
            } : nil,
            moveDown: reorderable && !isDisplayingFilteredSubset && value.indices.contains(index + 1) ? {
                guard value.indices.contains(index), value.indices.contains(index + 1) else { return }
                value.swapAt(index, index + 1)
            } : nil
        )
    }
}
#endif
