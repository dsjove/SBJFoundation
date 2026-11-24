import SBJLocalization
import SwiftUI
import SBJUIVocabulary
import SBJHelp
import SBJFileResources

public extension SBJBundledContentReference {
    static var tagFilterHelp: Self { .help("Tag Filter", bundle: .module) }
}

/// Live ordered-set editor. Every change is applied to the supplied binding;
/// persistence stays with the client through onChange. Done only dismisses.
@MainActor
public struct TagFilterEditor<Tag: Tagging>: View where Tag.ID: Hashable {
    @Environment(\.dismiss) private var dismiss
    @Binding private var filter: TagFilter<Tag>
    private let availableTags: [Tag]
    private let onChange: (() -> Void)?
    private let onDone: (() -> Void)?

    public init(filter: Binding<TagFilter<Tag>>, availableTags: [Tag],
                onChange: (() -> Void)? = nil,
                onDone: (() -> Void)? = nil) {
        _filter = filter
        self.availableTags = availableTags
        self.onChange = onChange
        self.onDone = onDone
    }

    public var body: some View {
        NavigationStack {
            Form {
                HStack(spacing: 12) {
                    Text(SBJTagNomenclature.tagsFilterStartAll.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    includeExcludePicker($filter.startAll)
                    trailingSpace
                }
                .accessibilityLabel(SBJTagNomenclature.tagsFilterStart.accessibility.accessibilityLabel!)

                ForEach(filter.operations.indices, id: \.self) { index in
                    HStack(spacing: 12) {
                        tagMenu(at: index)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        includeExcludePicker($filter.operations[index].add)
                        SBJRemoveButton(accessibilityLabel: SBJTagNomenclature.tagsRemoveFilterRule.accessibility.accessibilityLabel!) {
                            filter.operations.remove(at: index)
                        }
                        .frame(width: 28)
                    }
                }

                if !filter.invalidTagIDs(availableTags: availableTags).isEmpty {
                    Text(SBJTagNomenclature.tagsFilterInvalid.details!)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(SBJTagNomenclature.tagsFilterTitle.title)
#if !os(watchOS)
            .sbjInlineNavigationTitle()
#endif
            .onChange(of: filter) { _, _ in onChange?() }
            .toolbar {
                ToolbarItemGroup(placement: leadingToolbarPlacement) {
                    Button(SBJCommonNomenclature.done.title) {
                        if let onDone { onDone() } else { dismiss() }
                    }
                    Button(SBJTagNomenclature.tagsFilterClear.title) { filter.operations.removeAll() }
                        .disabled(filter.operations.isEmpty)
                        .help(SBJTagNomenclature.tagsFilterClear.details!)
                }
                ToolbarItemGroup(placement: trailingToolbarPlacement) {
                    SBJAddButton(accessibilityLabel: SBJTagNomenclature.tagsAddFilterRule.title, accessibilityHint: SBJTagNomenclature.tagsAddFilterRule.details!, action: addRule)
                        .help(SBJTagNomenclature.tagsAddFilterRule.details!)
#if !os(watchOS)
                    SBJHelpLink(asset: .tagFilterHelp, configuration: .editTagsHelp)
#endif
                }
            }
        }
    }

    private var trailingSpace: some View {
        Color.clear.frame(width: 28, height: 1).accessibilityHidden(true)
    }

    private func addRule() {
        if let tag = availableTags.sorted().first {
            filter.operations.append(.init(tagID: tag.id, add: true))
        } else {
            filter.operations.append(.init(criterion: .hasTag, add: true))
        }
    }

    private func includeExcludePicker(_ selection: Binding<Bool>) -> some View {
        Picker(SBJTagNomenclature.tagsFilterOperation.title, selection: selection) {
            Text(SBJTagNomenclature.tagsFilterInclude.title).tag(true)
            Text(SBJTagNomenclature.tagsFilterExclude.title).tag(false)
        }
        .labelsHidden()
        #if os(watchOS)
        .pickerStyle(.navigationLink)
        #else
        .pickerStyle(.segmented)
        .fixedSize()
        #endif
    }

    private func tagMenu(at index: Int) -> some View {
        let criterion = filter.operations[index].criterion
        let sorted = availableTags.sorted()
        let selected: Tag?
        let title: String
        let isMissing: Bool
        switch criterion {
        case .tag(let id):
            selected = sorted.first { $0.id == id }
            title = selected?.displayName ?? "Missing tag: \(id)"
            isMissing = selected == nil
        case .hasTag:
            selected = nil
            title = SBJTagNomenclature.tagsFilterHasTag.title
            isMissing = false
        }
        let choices = [SBJTagNomenclature.tagsFilterHasTag.title] + sorted.map(\.displayName)
        return SBJSelectionMenu {
            Button {
                filter.operations[index].criterion = .hasTag
            } label: {
                if criterion == .hasTag { Label(SBJTagNomenclature.tagsFilterHasTag) }
                else { Text(SBJTagNomenclature.tagsFilterHasTag.title) }
            }
            if !sorted.isEmpty { Divider() }
            ForEach(sorted, id: \.id) { tag in
                Button {
                    filter.operations[index].criterion = .tag(tag.id)
                } label: {
                    if criterion == .tag(tag.id) {
                        Label(tag.displayName, systemImage: "checkmark")
                    } else {
                        Text(tag.displayName)
                    }
                }
            }
        } label: {
            SBJSelectionMenuLabel(text: title, options: choices)
                .foregroundStyle(isMissing ? Color.red : Color.primary)
        }
        .accessibilityLabel("\(SBJTagNomenclature.tagsFilterRule.title): \(title)")
    }

    private var leadingToolbarPlacement: ToolbarItemPlacement {
#if os(macOS)
        .navigation
#else
        .topBarLeading
#endif
    }

    private var trailingToolbarPlacement: ToolbarItemPlacement {
#if os(macOS)
        .automatic
#else
        .topBarTrailing
#endif
    }
}
