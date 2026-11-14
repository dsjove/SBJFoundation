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

public extension SBJBundledContentReference {
	static var editTagsHelp: SBJBundledContentReference {
		.help("Edit Tags", bundle: .module)
	}
}

public extension SBJHelpConfiguration {
	static var editTagsHelp: Self {
		var configuration = SBJHelpConfiguration.standard
		configuration.addSymbolSet(SBJTagSymbology.self)
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
				SearchField("Search Tags", searching: $searchText)
					.padding(.horizontal)
				ScrollViewReader { proxy in
					List {
						if sortedTags.isEmpty {
							Button(action: addTag) {
								Label("Add Tag", symbol: SBJSymbology.add)
							}
							.buttonStyle(.borderedProminent)
						} else {
							ForEach(sortedTags) { tag in
								tagRow(tag)
							}
							.onDelete { offsets in
								let toBeDeleted = offsets.map { sortedTags[$0] }
								let shouldPrompt = toBeDeleted.allSatisfy { !$0.isSoleUser(user) }
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
					Button("Done") {
						if commit?() != false { dismiss() }
					}
				}
				ToolbarItemGroup(placement: trailingToolbarPlacement) {
					SBJAddButton("Tag", action: addTag)
	#if !os(watchOS)
					SBJHelpLink(asset: .editTagsHelp, configuration: .editTagsHelp)
	#endif
				}
			}
	#if !os(watchOS) && !os(tvOS)
			.sheet(item: $editColorTag) { tag in
				ColorPickerView(title: tag.name, selectedColor: Binding(
					get: { tag.color.swiftUIColor },
					set: { tag.color.swiftUIColor = $0 }
				))
#if !os(macOS)
				.presentationDetents([.medium])
#endif
			}
	#endif
			.alert(item: $deletionRequest) { request in
				Alert(
					title: Text(request.tags.count == 1 ? "Delete Tag" : "Delete Tags"),
					message: {
						if request.tags.count == 1, let name = request.tags.first?.name {
							Text("Are you sure you want to delete \"\(name)\"?")
						} else {
							Text("Are you sure you want to delete \(request.tags.count) tags?")
						}
					}(),
					primaryButton: .cancel(Text("Cancel")) {
						deletionRequest = nil
					},
					secondaryButton: .destructive(Text("Delete")) {
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
            .applyIf(Tag.propertyInfo(for: \Tag.color)?.accessibilityLabel) { view, label in
                view.accessibilityLabel(label)
            }
            .applyIf(Tag.propertyInfo(for: \Tag.color)?.accessibilityHint) { view, hint in
                view.accessibilityHint(hint)
            }
            .accessibilityValue(tag.displayName)
            .accessibilityAddTraits(.isButton)
    }

    private func tagNameControl(_ tag: Tag) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField("Name", text: Binding(
                get: { tag.name },
                set: { tag.name = $0 }
            ))
            .submitLabel(.done)
            .onSubmit { isTagFieldFocused = nil }
#if !os(watchOS) && !os(macOS)
            .autocapitalization(.none)
#endif
            .disableAutocorrection(true)
            .sbjFocusedControl(isFocused: $isTagFieldFocused, id: tag.id)
            .applyIf(Tag.propertyInfo(for: \Tag.name)?.accessibilityLabel) { view, label in
                view.accessibilityLabel(label)
            }
            if !tag.isSoleUser(user) {
                Text("(\(tag.userCount))")
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
        .applyIf(T.propertyInfo(for: \T.__tags)?.accessibilityLabel) { view, label in
            view.accessibilityLabel(label)
        }
        .applyIf(T.propertyInfo(for: \T.__tags)?.accessibilityHint) { view, hint in
            view.accessibilityHint(hint)
        }
        .accessibilityValue(tag.displayName)

        SBJSymbolButton(
            user.isTagPrimary(tag) ? SBJTagSymbology.primaryTag : SBJTagSymbology.notPrimaryTag,
            accessibilityLabel: T.propertyInfo(for: \T.__primaryTagID)?.accessibilityLabel ?? "Primary tag",
            accessibilityHint: T.propertyInfo(for: \T.__primaryTagID)?.accessibilityHint
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
