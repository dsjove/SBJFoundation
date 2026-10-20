import SwiftUI
import SBJUIVocabulary

import SBJDataDefinition
public struct TagsListView<T: TagUser>: View {
	private let user: T

	public init(user: T) {
		self.user = user
	}

	public var body: some View {
		let sortedTags = user.sortedTags
		HStack(spacing: 10) {
			if sortedTags.isEmpty {
				Text("No Tags")
					.font(.body)
					.italic(true)
					.padding(.trailing)
			} else {
				ForEach(sortedTags) { item in
					item.label(isPrimary: user.isTagPrimary(item))
				}
			}
		}
	}
}
