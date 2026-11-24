import SwiftUI

private struct SBJMultilineFieldModifier: ViewModifier {
    var isFocused: FocusState<Bool>.Binding
    let minHeight: CGFloat

    func body(content: Content) -> some View {
        content
            .focused(isFocused)
#if !os(watchOS) && !os(tvOS)
            .scrollContentBackground(.hidden)
#endif
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .frame(minHeight: minHeight)
            .sbjFieldChrome(isFocused.wrappedValue ? .focused : .standard)
    }
}

public extension View {
    func sbjMultilineField(
        isFocused: FocusState<Bool>.Binding,
        minHeight: CGFloat = 84
    ) -> some View {
        modifier(SBJMultilineFieldModifier(isFocused: isFocused, minHeight: minHeight))
    }
}
