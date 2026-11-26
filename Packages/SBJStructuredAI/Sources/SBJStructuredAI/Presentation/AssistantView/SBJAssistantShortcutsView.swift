import SwiftUI

@MainActor
struct SBJAssistantShortcutsView: View {
    let shortcuts: [SBJAssistantShortcut]
    let isEnabled: Bool
    let selectShortcut: (SBJAssistantShortcut) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(shortcuts) { shortcut in
                Button(shortcut.title) { selectShortcut(shortcut) }
                    .buttonStyle(.bordered)
                    .disabled(!isEnabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
