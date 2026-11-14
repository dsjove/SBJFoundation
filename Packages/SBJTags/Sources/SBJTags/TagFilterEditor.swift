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
                    Text("Begin with all")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    includeExcludePicker($filter.startAll)
                    trailingSpace
                }
                .accessibilityLabel("Starting set")

                ForEach(filter.operations.indices, id: \.self) { index in
                    HStack(spacing: 12) {
                        tagMenu(at: index)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        includeExcludePicker($filter.operations[index].add)
                        SBJRemoveButton(accessibilityLabel: "Remove rule") {
                            filter.operations.remove(at: index)
                        }
                        .frame(width: 28)
                    }
                }

                if !filter.invalidTagIDs(availableTags: availableTags).isEmpty {
                    Text("Red rules reference unavailable tags. Choose a current tag or remove the rule.")
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Tag Filter")
#if !os(watchOS)
            .sbjInlineNavigationTitle()
#endif
            .onChange(of: filter) { _, _ in onChange?() }
            .toolbar {
                ToolbarItemGroup(placement: leadingToolbarPlacement) {
                    Button("Done") {
                        if let onDone { onDone() } else { dismiss() }
                    }
                    Button("Clear") { filter.operations.removeAll() }
                        .disabled(filter.operations.isEmpty)
                        .help("Remove all rules, keeping the starting set")
                }
                ToolbarItemGroup(placement: trailingToolbarPlacement) {
                    SBJAddButton("Rule", action: addRule)
                        .disabled(availableTags.isEmpty)
                        .help("Add a tag rule")
#if !os(watchOS)
                    SBJHelpLink(asset: .tagFilterHelp)
#endif
                }
            }
        }
    }

    private var trailingSpace: some View {
        Color.clear.frame(width: 28, height: 1).accessibilityHidden(true)
    }

    private func addRule() {
        guard let tag = availableTags.sorted().first else { return }
        filter.operations.append(.init(tagID: tag.id, add: true))
    }

    private func includeExcludePicker(_ selection: Binding<Bool>) -> some View {
        Picker("Operation", selection: selection) {
            Text("Include").tag(true)
            Text("Exclude").tag(false)
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .fixedSize()
    }

    private func tagMenu(at index: Int) -> some View {
        let identifier = filter.operations[index].tagID
        let sorted = availableTags.sorted()
        let selected = sorted.first { $0.id == identifier }
        let title = selected?.displayName ?? "Missing tag: \(identifier)"
        let choices = sorted.map(\.displayName)
        return SBJSelectionMenu {
            ForEach(sorted, id: \.id) { tag in
                Button {
                    filter.operations[index].tagID = tag.id
                } label: {
                    if tag.id == identifier {
                        Label(tag.displayName, systemImage: "checkmark")
                    } else {
                        Text(tag.displayName)
                    }
                }
            }
        } label: {
            SBJSelectionMenuLabel(text: title, options: choices)
                .foregroundStyle(selected == nil ? Color.red : Color.primary)
        }
        .accessibilityLabel("Tag rule: \(title)")
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
