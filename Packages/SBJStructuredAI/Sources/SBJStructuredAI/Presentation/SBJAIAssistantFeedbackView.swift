#if canImport(FoundationModels) && canImport(SwiftUI) && !os(watchOS) && !os(tvOS)
import SwiftUI
import SBJLocalization

/// Reusable, opt-in feedback presentation. The host decides whether and where
/// to present it; no domain model or host persistence API is required.
///
/// Feedback events remain session-local and sanitized. Export is possible only
/// through the explicit ShareLink action; no diagnostics are sent automatically.
@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
@MainActor
public struct SBJAIAssistantFeedbackView: View {
    private typealias N = SBJAIAssistantNomenclature
    @Bindable private var feedback: SBJAIAssistantFeedback
    @Environment(\.dismiss) private var dismiss
    private let turnID: UUID
    private let revision: Int
    private let title: String

    public init(
        feedback: SBJAIAssistantFeedback,
        turnID: UUID,
        revision: Int,
        title: String = SBJAIAssistantNomenclature.feedbackTitle.title
    ) {
        self.feedback = feedback
        self.turnID = turnID
        self.revision = revision
        self.title = title
    }

    public var body: some View {
        NavigationStack {
            Form {
                Toggle(N.collectDiagnostics.title, isOn: $feedback.isEnabled)
                Text(N.privacyDescription.title)
                    .font(.caption)

                if feedback.isEnabled {
                    ForEach(feedback.events) { event in
                        VStack(alignment: .leading) {
                            Text(event.category.rawValue).font(.headline)
                            Text("\(event.phase.rawValue) · \(event.outcome.rawValue) · \(event.diagnosticCode)")
                                .font(.caption)
                            Text(event.timestamp, style: .time).font(.caption2)
                        }
                    }
                    ShareLink(item: feedback.exportJSON) {
                        Label(N.exportDiagnostics.title, systemImage: "square.and.arrow.up")
                    }
                    Button(N.deleteDiagnostics.title, role: .destructive) {
                        feedback.deleteAll()
                    }
                }

                Section(N.reportMistake.title) {
                    Button(N.wrongField.title) { record(.wrongField) }
                    Button(N.wrongIntent.title) { record(.wrongIntent) }
                    Button(N.wrongValue.title) { record(.wrongValue) }
                }
                .disabled(!feedback.isEnabled)
            }
            .navigationTitle(title)
            .toolbar { Button(N.done.title) { dismiss() } }
        }
        .frame(minWidth: 360, minHeight: 360)
    }

    private func record(_ category: SBJAIAssistantDiagnostic.Category) {
        feedback.recordCorrection(turnID: turnID, revision: revision, category: category)
    }
}
#endif
