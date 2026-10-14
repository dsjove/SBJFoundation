#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJDictionaryEditor<Key: Codable & Hashable, Value: Codable>: View {
    private struct DisplayEntry: Identifiable {
        let key: Key
        let value: Value
        var id: Key { key }
    }
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
    var headerOnly: Bool = false
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

    private var displayEntries: [DisplayEntry] {
        SBJCollectionOrdering.sortedEntries(value).compactMap { key, entryValue in
            let keyLabel = String(describing: key)
            guard navigationTarget?.contains(context.navigationPath + [keyLabel]) == true || searchCriteria.includes(
                isChanged: entryHasChanged(key: key, value: entryValue),
                containsEmptyContent: SBJContentCheck.containsEmptyContent(
                    entryValue,
                    treatingAsLeaf: { registry.hasCustomEditor($0) }
                ),
                matchesSearch: { query in
                    if sbjPredicated(label, search: query) { return true }
                    return sbjPredicated(
                        label: String(describing: key),
                        value: entryValue,
                        search: query
                    )
                }
            ) else { return nil }
            return DisplayEntry(key: key, value: entryValue)
        }
    }

    private func entryHasChanged(key: Key, value entryValue: Value) -> Bool {
        guard let originalValue, originalValue.keys.contains(key) else { return true }
        guard let old = originalValue[key] else { return true }
        return !SBJStructuralCompare.equals(entryValue, old)
    }

    private var addCandidate: (Key, Value)? {
        guard let key = registry.create(Key.self),
              !value.keys.contains(key),
              let entryValue = registry.create(Value.self) else { return nil }
        return (key, entryValue)
    }

    private var presentationRows: [SBJEditorPresentationRow<DisplayEntry>] {
        displayEntries.map { entry in
            let keyText = String(reflecting: entry.key)
            return SBJEditorPresentationRow(
                context: SBJEditTraversalContext(
                    treeLevel: context.treeLevel + 1,
                    itemIdentifier: context.itemIdentifier.appending("key:\(keyText)"),
                    indexPath: context.indexPath.appending("key:\(keyText)"),
                    navigationPath: context.navigationPath + [String(describing: entry.key)]
                ),
                content: entry
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
                            guard let (key, entryValue) = addCandidate else { return }
                            value.updateValue(entryValue, forKey: key)
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

            if resolvedIsExpanded && !headerOnly {
                VStack(alignment: .leading, spacing: 10) {
                    if displayEntries.isEmpty {
                        SBJEditorEmptyDisclosureContent(
                            message: value.isEmpty
                                ? "No entries. Use + to add one."
                                : "No entries match the current filters."
                        )
                    }

                    ForEach(presentationRows) { row in
                        let entry = row.content
                        let key = entry.key
                        let entryValue = entry.value
                        let keyLabel = String(describing: key)
                        let itemContext = row.context
                        let entryChanged = entryHasChanged(key: key, value: entryValue)
                        let entrySearchCriteria = searchCriteria.descendingPastMatchedLabels(label, keyLabel)
                        SBJDictionaryEntryEditor(
                            key: key,
                            entryValue: Binding(
                                get: { value[key] ?? entryValue },
                                set: { value.updateValue($0, forKey: key) }
                            ),
                            originalValue: originalValue?[key],
                            entryIsChanged: entryChanged,
                            registry: registry,
                            textStyle: textStyle,
                            integerRange: integerRange,
                            numberRange: numberRange,
                            focusRequest: focusRequest,
                            context: itemContext,
                            rename: { old, replacement in
                                value.sbjRenameKey(old, to: replacement)
                            },
                            remove: { value.removeValue(forKey: key) }
                        )
                        .environment(\.sbjEditorSearchCriteria, entrySearchCriteria)
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
