import SwiftData
import SwiftUI
import SBJDataDefinition
import SBJHelp
import SBJUIVocabulary
import SBJFileResources

public extension SBJBundledContentReference {
    static var editTags: SBJBundledContentReference {
        .help("Edit Tags", bundle: .module)
    }
}

public struct TagsEditSheet<T: TagUser, B: TagBag> : View where T.Tag == B.Tag {
	typealias Tag = T.Tag

	@Environment(\.dismiss) private var dismiss

	@Bindable var tagBag: B
	let user: T?

	@State private var searchText = ""
	@State private var editColorTag: Tag?
	@FocusState private var isTagFieldFocused: Tag.ID?
	@State private var lastAddedTagID: Tag.ID?

	struct DeletionRequest: Identifiable {
		let id = UUID()
		let tags: [Tag]
	}
	@State private var deletionRequest: DeletionRequest?

	public init(tagBag: B, user: T?) {
		self.tagBag = tagBag
		self.user = user
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
								HStack {
									Rectangle()
										.fill(tag.color.swiftUIColor)
										.frame(width: 44, height: 44)
										.cornerRadius(8.0)
										.onTapGesture {
											editColorTag = tag
										}
                                        .applyIf(Tag.propertyInfo(for: \Tag.color)?.accessibilityLabel) { view, label in
                                            view.accessibilityLabel(label)
                                        }
                                        .applyIf(Tag.propertyInfo(for: \Tag.color)?.accessibilityHint) { view, hint in
                                            view.accessibilityHint(hint)
                                        }
                                        .accessibilityValue(tag.displayName)
                                        .accessibilityAddTraits(.isButton)
									VStack(alignment: .leading, spacing: 2) {
										TextField("Name", text: Binding(
											get: { tag.name },
											set: { tag.name = $0 }
										))
										.submitLabel(.done)
										.onSubmit {
												isTagFieldFocused = nil
										}
	#if !os(watchOS)
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
									//Implicit Spacer() with List rows
									if let user {
										Toggle(isOn: Binding(
											get: { user.hasTag(tag) },
											set: { newValue in
												if newValue {
													user.addTag(tag)
												} else {
													user.removeTag(tag)
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
                                            user.isTagPrimary(tag)
                                                ? SBJTagSymbology.primaryTag
                                                : SBJTagSymbology.notPrimaryTag,
                                            propertyInfo: T.propertyInfo(for: \T.__primaryTagID)
                                                ?? SBJPropertyInfo(
                                                    summary: "Primary tag",
                                                    details: "Toggles the primary tag.",
                                                    accessibilityLabel: "Primary tag"
                                                )
                                        ) {
                                            user.togglePrimary(tag)
                                        }
                                        .accessibilityValue(tag.displayName)
									}
								}
								.background(
									RoundedRectangle(cornerRadius: 12, style: .continuous)
										.fill((user?.isTagPrimary(tag) ?? false) ? Color.secondary.opacity(0.13) : Color.clear)
										.padding(-8)
								)
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
	#if !os(watchOS) && !os(tvOS)
			.navigationBarTitle(tagBag.title, displayMode: .inline)
	#else
			.navigationBarTitle(tagBag.title)
	#endif
			.toolbar {
				ToolbarItemGroup(placement: .topBarLeading) {
					Button("Done") {
						dismiss()
					}
				}
				ToolbarItemGroup(placement: .topBarTrailing) {
					SBJAddButton("Tag", action: addTag)
	#if !os(watchOS)
					SBJHelpLink(asset: .editTags, configuration: SBJTagSymbology.helpConfiguration)
	#endif
				}
			}
	#if !os(watchOS) && !os(tvOS)
			.sheet(item: $editColorTag) { tag in
				ColorPickerView(title: tag.name, selectedColor: Binding(
					get: { tag.color.swiftUIColor },
					set: { tag.color.swiftUIColor = $0 }
				))
				.presentationDetents([.medium])
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
		.presentationDetents([.large])
	}

	func addTag() {
		let newTag = tagBag.addNewTag(named: searchText)
		user?.addTag(newTag)
		searchText = ""
		isTagFieldFocused = newTag.id
		lastAddedTagID = newTag.id
	}
}
