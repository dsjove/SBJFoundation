import SwiftUI

#if !os(watchOS)
public extension View {
	@ViewBuilder
	func sbjInlineNavigationTitle() -> some View {
		#if os(tvOS)
		self
		#else
		self.navigationBarTitleDisplayMode(.inline)
		#endif
	}
}
#endif
