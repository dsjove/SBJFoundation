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
    @State private var disclosureState = SBJEditorDisclosureState()
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

    private var displayElements: [Element] {
        SBJCollectionOrdering.sorted(value).filter { element in
            let itemTitle = SBJCollectionItemIdentification.title(for: element, itemTitleKey: itemTitleKey)
            if navigationTarget?.contains(context.navigationPath + [itemTitle]) == true {
                return true
            }
            return searchCriteria.includes(
                isChanged: originalValue?.contains(element) != true,
                containsEmptyContent: SBJContentCheck.containsEmptyContent(
                    element,
                    treatingAsLeaf: { registry.hasCustomEditor($0) }
                ),
                matchesSearch: { query in
                    if sbjPredicated(label, search: query) { return true }
                    return sbjPredicated(
                        label: SBJCollectionItemIdentification.title(for: element, itemTitleKey: itemTitleKey),
                        value: element,
                        search: query
                    )
                }
            )
        }
    }

    private var addCandidate: Element? {
        guard let candidate = registry.create(Element.self), !value.contains(candidate) else { return nil }
        return candidate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SBJEditorDisclosureHeader(
                "\(label) (\(value.count))",
                treeLevel: context.treeLevel,
                isExpanded: disclosureBinding,
                leadingActions: AnyView(
                    HStack(spacing: 6) {
                        if let itemActions { itemActions.leadingView }
                        SBJAddButton(label) {
                            guard let candidate = addCandidate else { return }
                            value.insert(candidate)
                            disclosureState.userIsExpanded = true
                        }
                        .disabled(addCandidate == nil)
                    }
                ),
                trailingActions: AnyView(
                    HStack(spacing: 6) {
                        if let itemActions { itemActions.trailingView }
                    }
                )
            )

            if resolvedIsExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if displayElements.isEmpty {
                        SBJEditorEmptyDisclosureContent(
                            message: value.isEmpty
                                ? "No entries. Use + to add one."
                                : "No entries match the current filters."
                        )
                    }

                    ForEach(displayElements, id: \.self) { element in
                        let stableIdentifier = "\(String(reflecting: type(of: element))):\(String(reflecting: element))"
                        let itemTitle = SBJCollectionItemIdentification.title(for: element, itemTitleKey: itemTitleKey)
                        let itemContext = SBJEditTraversalContext(
                            treeLevel: context.treeLevel + 1,
                            itemIdentifier: context.itemIdentifier.appending("item:\(stableIdentifier)"),
                            indexPath: context.indexPath.appending("item:\(stableIdentifier)"),
                            navigationPath: context.navigationPath + [itemTitle]
                        )
                        let itemSearchCriteria = searchCriteria.descendingPastMatchedLabels(label, itemTitle)
                        SBJSetEntryEditor(
                            element: element,
                            originalElement: originalValue?.contains(element) == true ? element : nil,
                            title: itemTitle,
                            registry: registry,
                            textStyle: textStyle,
                            integerRange: integerRange,
                            numberRange: numberRange,
                            focusRequest: focusRequest,
                            context: itemContext,
                            replace: { old, replacement in
                                value.sbjReplace(old, with: replacement)
                            },
                            remove: { value.remove(element) }
                        )
                        .environment(\.sbjEditorSearchCriteria, itemSearchCriteria)
                        .sbjEditorNavigationAnchor(for: itemContext.navigationPath)
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
}
#endif
