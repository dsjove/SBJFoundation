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
    @Environment(\.sbjEditorDisclosureMode) private var disclosureMode
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
        presentationModel.commitNavigationExpansion(
            target: navigationTarget,
            path: context.navigationPath,
            id: context.itemIdentifier
        )
    }

    private var resolvedIsExpanded: Bool {
        presentationModel.resolved(
            context.itemIdentifier,
            mode: disclosureMode,
            search: searchIsExpanded,
            navigation: navigationIsExpanded
        )
    }

    private var disclosureBinding: Binding<Bool> {
        Binding(
            get: { resolvedIsExpanded },
            set: { presentationModel.setUserExpansion($0, for: context.itemIdentifier, search: searchIsExpanded) }
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

    private var presentationRows: [SBJEditorPresentationRow<Element>] {
        displayElements.map { element in
            let stable = "\(String(reflecting: type(of: element))):\(String(reflecting: element))"
            let title = SBJCollectionItemIdentification.title(for: element, itemTitleKey: itemTitleKey)
            return SBJEditorPresentationRow(
                context: SBJEditTraversalContext(
                    treeLevel: context.treeLevel + 1,
                    itemIdentifier: context.itemIdentifier.appending("item:\(stable)"),
                    indexPath: context.indexPath.appending("item:\(stable)"),
                    navigationPath: context.navigationPath + [title]
                ),
                content: element
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
                        if let itemActions { itemActions.leadingView }
                        SBJAddButton(label) {
                            guard let candidate = addCandidate else { return }
                            value.insert(candidate)
                            presentationModel.open(context.itemIdentifier)
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

                    ForEach(presentationRows) { row in
                        let element = row.content
                        let itemTitle = SBJCollectionItemIdentification.title(for: element, itemTitleKey: itemTitleKey)
                        let itemContext = row.context
                        let itemSearchCriteria = searchCriteria.descendingPastMatchedLabels(label, itemTitle)
                        SBJSetEntryEditor(
                            element: element,
                            originalElement: originalValue?.contains(element) == true ? element : nil,
                            title: itemTitle,
                            registry: registry,
                            context: itemContext,
                            configuration: .init(
                                textStyle: textStyle,
                                integerRange: integerRange,
                                numberRange: numberRange,
                                focusRequest: focusRequest
                            ),
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

                SBJEditorLevelExitDivider(level: context.treeLevel)
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
