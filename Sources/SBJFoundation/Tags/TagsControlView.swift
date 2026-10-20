import SwiftUI
import SBJUIVocabulary

import SBJDataDefinition
public struct TagsControlView<T: TagUser>: View {
	private let user: T
	private let showTagsSheet: (()->())?

	public init(user: T, showTagsSheet: (() -> Void)?) {
		self.user = user
		self.showTagsSheet = showTagsSheet
	}

	public var body: some View {
		HStack {
			if let showTagsSheet {
				Button {
					showTagsSheet()
				} label: {
					Label("Edit Tags", symbol: SBJTagSymbology.tags)
				}
				.controlSize(.regular)
				.buttonStyle(.borderedProminent)
			}
			let sortedTags = user.sortedTags
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 10) {
					if sortedTags.isEmpty {
						Text("No Tags")
							.font(.body)
							.italic(true)
							.padding(.trailing)
							.onTapGesture(count: 1) {
								if let showTagsSheet {
									showTagsSheet()
								}
							}
					} else {
						ForEach(sortedTags) { item in
							item.label(isPrimary: user.isTagPrimary(item))
						}
					}
				}
				.padding()
			}
		}
	}
}
