import SwiftUI
import SBJDataDefinition
import SBJLocalization
internal import Combine

public protocol SlideView: View {
	associatedtype Element: Identifiable
	init(element: Element, focused: Bool)
}

public struct SlideshowView<Content: SlideView>: View {
	public typealias Element = Content.Element
	public let elements: [Element]
	public let onDismiss: () -> Void

	@Environment(\.dismiss) private var dismiss

	@State private var index: Int = 0
	@State private var isPlaying: Bool = true
	@State private var focused: Bool = false

	private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

	public init(elements: [Element], onDismiss: @escaping () -> Void) {
		self.elements = elements
		self.onDismiss = onDismiss
	}

	public var body: some View {
		ZStack {
			Color.white
				.ignoresSafeArea()
			if elements.isEmpty {
				VStack(spacing: 16) {
					Spacer()
					Text("Nothing to show.")
						.foregroundColor(.secondary)
						.font(.title3)
					Spacer()
					Button {
						onDismiss()
						dismiss()
					} label: {
						Label("Close", symbol: SBJSymbology.close)
							.labelStyle(.titleAndIcon)
							.font(.title2)
					}
					.padding(.bottom, 40)
				}
				.padding()
			} else {
				VStack() {
					Content(element: elements[index], focused: focused)
						.id(elements[index].id)
						.transition(.opacity)
						.animation(.easeInOut(duration: 0.35), value: index)
					Spacer()
				}
				.contentShape(Rectangle())
				.onTapGesture { focused.toggle() }
				.onReceive(timer) { _ in
					guard isPlaying, !elements.isEmpty else { return }
					withAnimation(.easeInOut(duration: 0.35)) {
						index = (index + 1) % elements.count
					}
				}

				if !focused {
					VStack {
						HStack {
							Button {
								onDismiss()
								dismiss()
							} label: {
								Image(symbol: SBJSymbology.close)
									.font(.title2)
							}
							Spacer()
							Button {
								index = index == 0 ? elements.count - 1 : (index - 1) % elements.count
							} label: {
								Image(symbol: SBJSymbology.previous)
									.font(.title2)
							}
							Button {
								isPlaying.toggle()
							} label: {
								Image(symbol: isPlaying ? SBJSymbology.pause : SBJSymbology.play)
									.font(.title2)
							}
							Button {
								index = (index + 1) % elements.count
							} label: {
								Image(symbol: SBJSymbology.next)
									.font(.title2)
							}
						}
						.padding(.horizontal, 20)
						.padding(.top, 20)

						Spacer()
					}
					.transition(.opacity.combined(with: .move(edge: .top)))
					.animation(.easeInOut(duration: 0.2), value: focused)
					.ignoresSafeArea(edges: .top)
				}
			}
		}
		#if !os(watchOS) && !os(tvOS)
		.statusBarHidden(true)
		#endif
	}
}

private struct IdentifiableInt: Identifiable, ExpressibleByIntegerLiteral {
	typealias IntegerLiteralType = Int
	let id: Int
	init(id: Int) {
		self.id = id
	}
	init(integerLiteral value: Int) {
		self.id = value
	}
}

private struct TestSlideView: SlideView {
	let element: IdentifiableInt
	let focused: Bool

	init(element: IdentifiableInt, focused: Bool) {
		self.element = element
		self.focused = focused
	}

	var body: some View {
		Text("\(element.id)")
		.bold(focused)
	}
}

#Preview {
  SlideshowView<TestSlideView>(elements: [0, 1, 2, 3]) {
		// no-op dismiss
	}
}
