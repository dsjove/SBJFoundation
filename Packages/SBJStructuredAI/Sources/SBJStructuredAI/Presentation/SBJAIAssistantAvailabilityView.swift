#if canImport(SwiftUI) && !os(watchOS) && !os(tvOS)
import SwiftUI

@available(iOS 17.0, macOS 14.0, macCatalyst 17.0, visionOS 1.0, *)
@MainActor
public struct SBJAIAssistantAvailabilityView: View {
    public let state: SBJAIAssistantState
    public init(state: SBJAIAssistantState) { self.state = state }

    public var body: some View {
        switch state {
        case .ready:
            EmptyView()
        case .unsupported:
            ContentUnavailableView("Assistant Not Supported", systemImage: "sparkles.slash",
                description: Text("Apple Intelligence is not available on this device or system version."))
                .accessibilityIdentifier("assistant.availability.unsupported")
        case .disabled:
            ContentUnavailableView("Apple Intelligence Is Off", systemImage: "gear",
                description: Text("Enable Apple Intelligence in Settings (System Settings on Mac) to use the Assistant."))
                .accessibilityIdentifier("assistant.availability.disabled")
        case .preparing:
            VStack(spacing: 12) {
                ProgressView()
                Text("Preparing Apple Intelligence").font(.headline)
                Text("The language model is not ready. It may be downloading or updating. The Assistant will become available when the model is ready.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("assistant.availability.preparing")
        case .unknown:
            ContentUnavailableView("Assistant Unavailable", systemImage: "exclamationmark.circle",
                description: Text("Apple Intelligence is unavailable. Please try again later."))
                .accessibilityIdentifier("assistant.availability.unknown")
        }
    }
}
#endif
