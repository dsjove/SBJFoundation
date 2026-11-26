import SwiftUI
import SBJLocalization

@MainActor
struct SBJAssistantTranscriptView: View {
    private typealias N = SBJAssistantNomenclature
    let messages: [SBJAssistantMessage]
    let diagnostics: [String]
    let showsDiagnostics: Bool
    let shortcuts: [SBJAssistantShortcut]
    let isActive: Bool
    let isResponding: Bool
    let displayError: (String) -> String
    let selectShortcut: (SBJAssistantShortcut) -> Void
    let stop: () -> Void

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if messages.isEmpty {
                        ContentUnavailableView {
                            Label(N.emptyTitle.title, systemImage: "sparkles")
                        } description: {
                            Text(N.emptyDescription.title)
                        }
                    }
                    ForEach(messages) { message in
                        SBJAssistantMessageView(message: message, displayError: displayError).id(message.id)
                    }
                    if showsDiagnostics && !diagnostics.isEmpty {
                        SBJAssistantDiagnosticsView(lines: diagnostics)
                    }
                    if !shortcuts.isEmpty {
                        SBJAssistantShortcutsView(shortcuts: shortcuts, isEnabled: isActive && !isResponding, selectShortcut: selectShortcut)
                    }
                    if isResponding {
                        HStack {
                            ProgressView(N.thinking.title)
                            Spacer()
                            Button(N.stop.title) { stop() }
                                .buttonStyle(.bordered)
                        }.id("responding")
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                if let id = messages.last?.id {
                    withAnimation { scroll.scrollTo(id, anchor: .bottom) }
                }
            }
            .onChange(of: isResponding) { _, responding in
                if responding { withAnimation { scroll.scrollTo("responding", anchor: .bottom) } }
            }

        }
    }
}
