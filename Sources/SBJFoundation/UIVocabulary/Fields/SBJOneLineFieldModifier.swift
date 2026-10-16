import SwiftUI

private struct SBJOneLineFieldModifier: ViewModifier {
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        field(content.focused($isFocused), focused: isFocused)
    }

    @ViewBuilder
    private func field<V: View>(_ content: V, focused: Bool) -> some View {
        content
#if !os(watchOS)
            .textFieldStyle(.plain)
#endif
            .sbjOneLineFieldPresentation(focused: focused)
    }
}

private struct SBJFocusableOneLineFieldModifier: ViewModifier {
    var isFocused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        content
            .focused(isFocused)
#if !os(watchOS)
            .textFieldStyle(.plain)
#endif
            .sbjOneLineFieldPresentation(focused: isFocused.wrappedValue)
    }
}

private struct SBJIdentifiedOneLineFieldModifier<Value: Hashable>: ViewModifier {
    var isFocused: FocusState<Value?>.Binding
    let id: Value

    func body(content: Content) -> some View {
        content
            .focused(isFocused, equals: id)
#if !os(watchOS)
            .textFieldStyle(.plain)
#endif
            .sbjOneLineFieldPresentation(focused: isFocused.wrappedValue == id)
    }
}

private extension View {
    func sbjOneLineFieldPresentation(focused: Bool) -> some View {
        padding(.horizontal, 7)
            .padding(.vertical, 4)
            .frame(minHeight: SBJUIAppearance.singleLineFieldMinimumHeight)
            .sbjFieldChrome(focused ? .focused : .standard)
            .multilineTextAlignment(.leading)
            .lineLimit(1)
            .submitLabel(.done)
    }
}

public extension View {
    func oneLiner() -> some View {
        modifier(SBJOneLineFieldModifier())
    }

    func oneLiner(isFocused: FocusState<Bool>.Binding) -> some View {
        modifier(SBJFocusableOneLineFieldModifier(isFocused: isFocused))
    }

    func oneLiner<Value: Hashable>(
        isFocused: FocusState<Value?>.Binding,
        id: Value
    ) -> some View {
        modifier(SBJIdentifiedOneLineFieldModifier(isFocused: isFocused, id: id))
    }
}
