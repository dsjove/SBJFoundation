#if !os(watchOS) && !os(tvOS)
import SwiftUI

import SBJDataDefinition
private struct PhotoEditGestureModifier<G: Gesture>: ViewModifier {
    let isEnabled: Bool
    let gesture: G

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.gesture(gesture)
        } else {
            content
        }
    }
}

extension View {
    func photoEditGesture<G: Gesture>(enabled: Bool, _ gesture: G) -> some View {
        modifier(PhotoEditGestureModifier(isEnabled: enabled, gesture: gesture))
    }
}
#endif
