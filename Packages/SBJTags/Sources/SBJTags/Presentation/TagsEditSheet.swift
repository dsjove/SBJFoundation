import SwiftUI
import SBJLocalization
import SBJFileResources
import SBJUIVocabulary
import SBJHelp

public enum SBJTagSymbology: SBJSymbolSet {
	public static let all: [String: SBJSymbol] = [
		"tags": .system("tag.fill"),
		"primaryTag": .system("star.fill"),
		"notPrimaryTag": .system("star"),
	]
}

/// Shared vocabulary for tag management and tag-filter actions.
public enum SBJTagNomenclature: SBJNomenclatureSet {
    public static let all: [String: SBJNomenclature] = [
        "tags.add-tag": .init(title: "Add Tag", details: "Creates a new tag.", symbol: SBJSymbology.add),
        "tags.edit-tags": .init(title: "Edit Tags", details: "Opens the tag editor.", symbol: SBJTagSymbology.tags),
        "tags.filter-start-all": .init(title: "Begin with all", details: "Begin filtering with every item included before applying rules."),
        "tags.filter-start": .init(title: "Starting Set", summary: "Choose whether to begin with all tags", details: "Begin with all includes every item before rules are applied; excluding the starting set begins with no items."),
        "tags.filter-has-tag": .init(title: "Has Tag", details: "Matches items with at least one tag.", symbol: SBJSymbology.checked),
        "tags.filter-clear": .init(title: "Clear Rules", summary: "Remove all rules while retaining the starting set", details: "Removes all tag filter rules without changing the starting set."),
        "tags.filter-rule": .init(title: "Tag Rule", summary: "Select the tag or condition for this rule", details: "Select a specific tag or a condition that matches items with any tag."),
        "tags.apply-tag": .init(title: "Apply Tag", details: "Applies this tag to the current item.", symbol: SBJSymbology.checked),
        "tags.set-primary": .init(title: "Set Primary Tag", details: "Sets this tag as the current item's primary tag.", symbol: SBJTagSymbology.notPrimaryTag),
        "tags.primary-marker": .init(title: "Primary Tag", details: "Identifies the item's primary tag.", symbol: SBJTagSymbology.primaryTag),
        "tags.add-filter-rule": .init(title: "Add Filter Rule", details: "Adds a rule for a selected tag or for any assigned tag. Choose Include or Exclude to determine what a matching rule does.", symbol: SBJSymbology.add),
        "tags.remove-filter-rule": .init(title: "Remove Filter Rule", details: "Removes an individual tag filter rule. Clear removes all rules without changing the starting set.", symbol: SBJSymbology.remove),
        "tags.filter-operation": .init(title: "Rule Operation", details: "Choose whether this rule includes or excludes matching items."),
        "tags.filter-include": .init(title: "Include", details: "Include items that match this rule."),
        "tags.filter-exclude": .init(title: "Exclude", details: "Exclude items that match this rule."),
        "tags.filter-invalid": .init(title: "Unavailable Tags", details: "Rules shown in red reference unavailable tags. Select a current tag or remove the rule."),
        "tags.search": .init(title: "Search Tags", details: "Find a tag by its name."),
        "tags.filter-title": .init(title: "Tag Filter", details: "Edit the rules that determine which tagged items are included."),
        "tags.delete-one": .init(title: "Delete Tag", details: "Deletes the selected tag."),
        "tags.delete-many": .init(title: "Delete Tags", details: "Deletes the selected tags."),
    ]
}

public extension SBJBundledContentReference {
	static var editTagsHelp: SBJBundledContentReference {
		.help("Edit Tags", bundle: .module)
	}
}

public extension SBJHelpConfiguration {
	static var editTagsHelp: Self {
		var configuration = SBJHelpConfiguration.standard
		configuration.addSymbolSet(SBJTagSymbology.self)
        configuration.addNomenclatureSet(SBJTagNomenclature.self)
		return configuration
	}
}

public struct TagsEditSheet<T: TagUser, B: TagBag> : View where T.Tag == B.Tag {
	typealias Tag = T.Tag

	@Environment(\.dismiss) private var dismiss

	@Bindable var tagBag: B
	private let referenceUser: T?
	private let valueUser: Binding<T>?
	private let commit: (() -> Bool)?

	/// Reads the latest value from a binding when editing a value-type user.
	private var user: T? { valueUser?.wrappedValue ?? referenceUser }

	/// Applies mutations to the owner of a struct, or to the original class instance.
	private func updateUser(_ change: (inout T) -> Void) {
		guard var current = user else { return }
		change(&current)
		valueUser?.wrappedValue = current
	}

	/// Value-backed assignments have no persistent inverse relationship.
	private func isSoleUser(_ tag: Tag) -> Bool {
		guard let referenceTag = tag as? any TaggingSwiftData else { return true }
		return referenceTag.isSoleUserID(user.map { AnyHashable($0.id) })
	}

	@State private var searchText = ""
	@State private var editColorTag: Tag?
	@FocusState private var isTagFieldFocused: Tag.ID?
	@State private var lastAddedTagID: Tag.ID?

	struct DeletionRequest: Identifiable {
		let id = UUID()
		let tags: [Tag]
	}
	@State private var deletionRequest: DeletionRequest?

	/// Existing reference-model initializer; source-compatible with SwiftData apps.
	/// Value-model users should use the Binding initializer instead.
	public init(tagBag: B, user: T?) {
		self.tagBag = tagBag
		self.referenceUser = user
		self.valueUser = nil
		self.commit = nil
	}

	/// Writable value-model initializer. Tag edits are written back to the owner.
	public init(tagBag: B, user: Binding<T>, onDone: (() -> Bool)? = nil) {
		self.tagBag = tagBag
		self.referenceUser = nil
		self.valueUser = user
		self.commit = onDone
	}

	public var body: some View {
		NavigationStack {
			VStack {
				let sortedTags = tagBag.tags(searchText)
				SearchField(SBJTagNomenclature.tagsSearch, searching: $searchText)
					.padding(.horizontal)
				ScrollViewReader { proxy in
					List {
						if sortedTags.isEmpty {
							Button(action: addTag) {
								Label(SBJTagNomenclature.tagsAddTag)
							}
							.buttonStyle(.borderedProminent)
						} else {
							ForEach(sortedTags) { tag in
								tagRow(tag)
							}
							.onDelete { offsets in
								let toBeDeleted = offsets.map { sortedTags[$0] }
								let shouldPrompt = toBeDeleted.allSatisfy { !isSoleUser($0) }
								if shouldPrompt {
									deletionRequest = DeletionRequest(tags: toBeDeleted)
								} else {
									withAnimation {
										tagBag.deleteTags(toBeDeleted)
									}
								}
							}
						}
					}
					.onChange(of: lastAddedTagID) { _, id in
						if let id {
							withAnimation {
								proxy.scrollTo(id, anchor: .center)
							}
							lastAddedTagID = nil
						}
					}
				}
			}
            .navigationTitle(tagBag.title)
#if !os(watchOS)
            .sbjInlineNavigationTitle()
#endif
			.toolbar {
				ToolbarItemGroup(placement: leadingToolbarPlacement) {
					Button(SBJCommonNomenclature.done.title) {
						if commit?() != false { dismiss() }
					}
				}
				ToolbarItemGroup(placement: trailingToolbarPlacement) {
					SBJAddButton(accessibilityLabel: SBJTagNomenclature.tagsAddTag.title, accessibilityHint: SBJTagNomenclature.tagsAddTag.details!, action: addTag)
	#if !os(watchOS)
					SBJHelpLink(asset: .editTagsHelp, configuration: .editTagsHelp)
	#endif
				}
			}
	#if !os(watchOS) && !os(tvOS)
			.sheet(item: $editColorTag) { tag in
				ColorPickerView(title: tag.name, selectedColor: Binding(
					get: { tag.color.swiftUIColor },
					set: { var t = tag; t.color.swiftUIColor = $0 }
				))
#if !os(macOS)
				.presentationDetents([.medium])
#endif
			}
	#endif
			.alert(item: $deletionRequest) { request in
				Alert(
					title: Text((request.tags.count == 1 ? SBJTagNomenclature.tagsDeleteOne : SBJTagNomenclature.tagsDeleteMany).title),
					message: {
						if request.tags.count == 1, let name = request.tags.first?.name {
							Text("Are you sure you want to delete \"\(name)\"?")
						} else {
							Text("Are you sure you want to delete \(request.tags.count) tags?")
						}
					}(),
					primaryButton: .cancel(Text(SBJCommonNomenclature.cancel.title)) {
						deletionRequest = nil
					},
					secondaryButton: .destructive(Text(SBJCommonNomenclature.delete.title)) {
						withAnimation {
							if let tags = deletionRequest?.tags {
								tagBag.deleteTags(tags)
							}
							deletionRequest = nil
						}
					}
				)
			}
		}
#if !os(macOS)
		.presentationDetents([.large])
#endif
	}

    @ViewBuilder
    private func tagRow(_ tag: Tag) -> some View {
        HStack {
            tagColorControl(tag)
            tagNameControl(tag)
            if let user {
                tagUserControls(tag, user: user)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill((user?.isTagPrimary(tag) ?? false) ? Color.secondary.opacity(0.13) : Color.clear)
                .padding(-8)
        )
    }

    private func tagColorControl(_ tag: Tag) -> some View {
        Rectangle()
            .fill(tag.color.swiftUIColor)
            .frame(width: 44, height: 44)
            .cornerRadius(8)
            .onTapGesture { editColorTag = tag }
            .applyIf(Tag.colorNomenclature.accessibilityLabel) { view, label in
                view.accessibilityLabel(label)
            }
            .applyIf(Tag.colorNomenclature.accessibilityHint) { view, hint in
                view.accessibilityHint(hint)
            }
            .accessibilityValue(tag.displayName)
            .accessibilityAddTraits(.isButton)
    }

    private func tagNameControl(_ tag: Tag) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField("Name", text: Binding(
                get: { tag.name },
                set: { var t = tag; t.name = $0 }
            ))
            .submitLabel(.done)
            .onSubmit { isTagFieldFocused = nil }
#if !os(watchOS) && !os(macOS)
            .autocapitalization(.none)
#endif
            .disableAutocorrection(true)
            .sbjFocusedControl(isFocused: $isTagFieldFocused, id: tag.id)
            .applyIf(Tag.nameNomenclature.accessibilityLabel) { view, label in
                view.accessibilityLabel(label)
            }
            if !isSoleUser(tag), let referenceTag = tag as? any TaggingSwiftData {
                Text("(\(referenceTag.userCount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func tagUserControls(_ tag: Tag, user: T) -> some View {
        Toggle(isOn: Binding(
            get: { user.hasTag(tag) },
            set: { enabled in
                updateUser { current in
                    if enabled { current.addTag(tag) }
                    else { current.removeTag(tag) }
                }
            }
        )) {}
        .toggleStyle(.sbjCheckbox)
        .applyIf(T.propertyNomenclature(for: \T.__tags)?.accessibilityLabel) { view, label in
            view.accessibilityLabel(label)
        }
        .applyIf(T.propertyNomenclature(for: \T.__tags)?.accessibilityHint) { view, hint in
            view.accessibilityHint(hint)
        }
        .accessibilityValue(tag.displayName)

        SBJSymbolButton(
            user.isTagPrimary(tag) ? SBJTagNomenclature.tagsPrimaryMarker.symbol! : SBJTagNomenclature.tagsSetPrimary.symbol!,
            accessibilityLabel: T.propertyNomenclature(for: \T.__primaryTagID)?.accessibilityLabel ?? "Primary tag",
            accessibilityHint: T.propertyNomenclature(for: \T.__primaryTagID)?.accessibilityHint
        ) {
            updateUser { $0.togglePrimary(tag) }
        }
        .accessibilityValue(tag.displayName)
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

	func addTag() {
		let newTag = tagBag.addNewTag(named: searchText)
		updateUser { $0.addTag(newTag) }
		searchText = ""
		isTagFieldFocused = newTag.id
		lastAddedTagID = newTag.id
	}
}
