import SwiftUI

private struct SBJFocusedControlModifier: ViewModifier {
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .sbjFieldChrome(isFocused ? .focused : .standard)
    }
}

private struct SBJBindingFocusedControlModifier: ViewModifier {
    let isFocused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        content
            .focused(isFocused)
            .sbjFieldChrome(isFocused.wrappedValue ? .focused : .standard)
    }
}

private struct SBJIdentifiedFocusedControlModifier<Value: Hashable>: ViewModifier {
    let isFocused: FocusState<Value?>.Binding
    let id: Value

    func body(content: Content) -> some View {
        content
            .focused(isFocused, equals: id)
            .sbjFieldChrome(isFocused.wrappedValue == id ? .focused : .standard)
    }
}

public extension View {
    /// Applies standard control chrome and tracks this view's focus internally.
    func sbjFocusedControl() -> some View {
        modifier(SBJFocusedControlModifier())
    }

    /// Applies standard control chrome using an existing Boolean focus binding.
    func sbjFocusedControl(isFocused: FocusState<Bool>.Binding) -> some View {
        modifier(SBJBindingFocusedControlModifier(isFocused: isFocused))
    }

    /// Applies standard control chrome using an existing identified focus binding.
    func sbjFocusedControl<Value: Hashable>(
        isFocused: FocusState<Value?>.Binding,
        id: Value
    ) -> some View {
        modifier(SBJIdentifiedFocusedControlModifier(isFocused: isFocused, id: id))
    }
}
