import Foundation
import SwiftUI
import SBJLocalization

/// Reusable, opt-in feedback presentation owned by the assistant view.
/// No domain model or host persistence API is required.
///
/// Feedback events remain session-local and sanitized. Export is possible only
/// through the explicit ShareLink action; no diagnostics are sent automatically.
@MainActor
public struct SBJAssistantFeedbackView: View {
	private typealias N = SBJAssistantNomenclature
	@Bindable private var feedback: SBJAssistantFeedback
	@Environment(\.dismiss) private var dismiss
	private let turnID: UUID
	private let revision: Int
	private let title: String

	public init(
		feedback: SBJAssistantFeedback,
		turnID: UUID,
		revision: Int,
		title: String = SBJAssistantNomenclature.feedbackTitle.title
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
							Text(event.diagnostic.category.rawValue).font(.headline)
							Text("\(event.diagnostic.phase.rawValue) · \(event.diagnostic.outcome.rawValue) · \(event.diagnostic.code)")
								.font(.caption)
							Text(event.timestamp, style: .time).font(.caption2)
						}
					}
#if !os(tvOS)
					ShareLink(item: feedback.exportJSON) {
						Label(N.exportDiagnostics.title, systemImage: "square.and.arrow.up")
					}
#endif
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
			.toolbar {
				ToolbarItem { Button(N.done.title) { dismiss() } }
			}
		}
		.frame(minWidth: 360, minHeight: 360)
	}

	private func record(_ category: SBJAssistantDiagnostic.Category) {
		feedback.recordCorrection(turnID: turnID, revision: revision, category: category)
	}
}
