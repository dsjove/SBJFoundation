import SwiftUI
import SBJLocalization

@MainActor
struct SBJAssistantToolbar: View {
    private typealias N = SBJAssistantNomenclature
    let hasSpeechToggle: Bool
    let hasShareDialog: Bool
    @Binding var speaksResponses: Bool
    let transcript: String
    let canShare: Bool

    var body: some View {
        HStack {
#if canImport(Speech) && canImport(AVFoundation) && !os(watchOS) && !os(tvOS)
            if hasSpeechToggle {
                Toggle(N.speakResponses.title, isOn: $speaksResponses)
                    .toggleStyle(.switch)
            }
#endif
            Spacer()
#if !os(tvOS)
            if hasShareDialog {
                ShareLink(item: transcript, subject: Text(N.shareSubject.title),
                          message: Text(N.shareMessage.title)) {
                    Label(N.shareTranscript.title, systemImage: "square.and.arrow.up")
                }
                .disabled(!canShare)
                .buttonStyle(.borderless)
                .accessibilityLabel(N.shareTranscript.accessibilityLabel ?? N.shareTranscript.title)
            }
#endif
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}
