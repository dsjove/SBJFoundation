import Foundation
import SwiftUI
import SBJLocalization

@MainActor
struct SBJAssistantMessageView: View {
    let message: SBJAssistantMessage
    let displayError: (String) -> String

    private var messageText: Text {
        switch message.speaker {
        case .assistant:
            Text((try? AttributedString(markdown: message.text)) ?? AttributedString(message.text))
        case .diagnostic:
            Text(message.text).font(.system(.caption, design: .monospaced))
        case .error:
            Text(displayError(message.text))
        case .user:
            Text(message.text)
        }
    }

    private var bubbleColor: Color {
        switch message.speaker {
        case .user: Color.accentColor.opacity(0.12)
        case .diagnostic: Color.orange.opacity(0.07)
        default: Color.secondary.opacity(0.09)
        }
    }

    var body: some View {
        HStack {
            if message.speaker == .user { Spacer(minLength: 45) }
            VStack(alignment: .leading, spacing: 5) {
                Text(message.speaker.nomenclature.title)
                    .font(.caption).bold().foregroundStyle(.secondary)
                messageText
#if !os(watchOS) && !os(tvOS)
                    .textSelection(.enabled)
#endif
            }
            .padding(12)
            .background(bubbleColor, in: RoundedRectangle(cornerRadius: 12))
            if message.speaker != .user { Spacer(minLength: 45) }
        }
    }
}
