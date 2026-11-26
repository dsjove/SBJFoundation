import SwiftUI

@MainActor
public struct SBJAssistantAvailabilityView: View {
	public let state: SBJAssistantState
	public let providerName: String?
	public let message: String?
	public init(state: SBJAssistantState, providerName: String? = nil, message: String? = nil) {
		self.state = state
		self.providerName = providerName
		self.message = message
	}

	public var body: some View {
		switch state {
		case .ready:
			EmptyView()
		case .unsupported:
			ContentUnavailableView("Assistant Not Supported", systemImage: "sparkles.slash",
				description: Text(message ?? "\(providerName ?? "The assistant") is not available on this device or system version."))
				.accessibilityIdentifier("assistant.availability.unsupported")
		case .disabled:
			ContentUnavailableView("\(providerName ?? "Assistant") Is Off", systemImage: "gear",
				description: Text(message ?? "Enable \(providerName ?? "the assistant") to continue."))
				.accessibilityIdentifier("assistant.availability.disabled")
		case .preparing:
			VStack(spacing: 12) {
				ProgressView()
				Text("Preparing \(providerName ?? "Assistant")").font(.headline)
				Text(message ?? "The assistant is preparing. It will become available when ready.")
					.foregroundStyle(.secondary).multilineTextAlignment(.center)
			}
			.padding()
			.accessibilityElement(children: .combine)
			.accessibilityIdentifier("assistant.availability.preparing")
		case .unknown:
			ContentUnavailableView("Assistant Unavailable", systemImage: "exclamationmark.circle",
				description: Text(message ?? "\(providerName ?? "The assistant") is unavailable. Please try again later."))
				.accessibilityIdentifier("assistant.availability.unknown")
		}
	}
}
