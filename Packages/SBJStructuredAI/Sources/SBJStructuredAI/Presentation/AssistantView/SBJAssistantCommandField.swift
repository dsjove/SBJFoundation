import SwiftUI
import SBJLocalization

#if !os(watchOS) && !os(tvOS)
/// A multiline command field whose hardware Return sends and Shift–Return edits.
/// Use the native selection so inserting a line break respects the caret or selection.
@available(iOS 18.0, macOS 15.0, macCatalyst 18.0, visionOS 2.0, *)
@MainActor
struct SBJAssistantCommandField: View {
    @Binding var draft: String
    let inputFocused: FocusState<Bool>.Binding
    let send: () -> Void
    @State private var selection: TextSelection?

    var body: some View {
        TextField(SBJAssistantNomenclature.prompt.title, text: $draft,
                  selection: $selection, axis: .vertical)
            .lineLimit(1...5)
            .focused(inputFocused)
            .onKeyPress(.return, phases: .down) { press in
                let modifiers = press.modifiers.intersection([.shift, .control, .option, .command])
                if modifiers == .shift {
                    return insertNewline() ? .handled : .ignored
                }
                guard modifiers.isEmpty else { return .ignored }
                send()
                return .handled
            }
            .onSubmit(send)
    }

    private func insertNewline() -> Bool {
        // A nil or multiple selection is left to the system text editor.
        guard let selection, case .selection(let range) = selection.indices else {
            return false
        }
        let offset = range.lowerBound.utf16Offset(in: draft)
        var updated = draft
        updated.replaceSubrange(range, with: "\n")
        draft = updated
        self.selection = TextSelection(insertionPoint: String.Index(utf16Offset: offset + 1, in: updated))
        return true
    }
}
#endif
