import SwiftUI

public extension Tagging {
	var foregroundColor: Color {
		self.color.isLight ? .black : .white
	}

	var backgroundColor: Color {
		self.color.swiftUIColor
	}

	@ViewBuilder
	func label(isPrimary: Bool = false) -> some View {
		Text(displayName)
			.font(.caption).bold()
			.padding(.horizontal, 8)
			.padding(.vertical, 4)
			.background(backgroundColor)
			.foregroundColor(foregroundColor)
			.cornerRadius(8)
			.overlay(
				RoundedRectangle(cornerRadius: 8)
					.stroke(isPrimary ? Color.black : Color.clear, lineWidth: 2)
			)
	}
}

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
