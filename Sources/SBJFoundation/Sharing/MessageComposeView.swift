#if os(iOS) && canImport(MessageUI)
import Foundation
import MessageUI
import SwiftUI
import UIKit

public struct ComposedMessage: Sendable {
	public struct Attachment: Sendable {
		public let content: SBJResourceContent
		public let filename: String

		public init(content: SBJResourceContent, filename: String) {
			self.content = content
			let resolved = filename.sanitizedFilename(contentType: content.contentType)
			self.filename = resolved.isEmpty
				? "Attachment".sanitizedFilename(contentType: content.contentType)
				: resolved
		}
	}

	public let recipients: [String]
	public let body: String
	public let attachments: [Attachment]

	public init(recipients: [String], body: String, attachments: [Attachment]) {
		self.recipients = Self.cleanedRecipients(recipients)
		self.body = body
		self.attachments = attachments
	}

	public init(recipients: String, body: String, attachments: [Attachment]) {
		self.init(
			recipients: recipients.split(separator: ",").map(String.init),
			body: body,
			attachments: attachments
		)
	}

	private static func cleanedRecipients(_ recipients: [String]) -> [String] {
		recipients.compactMap {
			let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
			return trimmed.isEmpty ? nil : trimmed
		}
	}
}

public enum MessageComposeError: LocalizedError, Sendable {
	case cannotSendText
	case cannotSendAttachments
	case unsupportedAttachmentType(String)
	case attachmentRejected(String)

	public var errorDescription: String? {
		switch self {
		case .cannotSendText:
			"This device cannot send text messages."
		case .cannotSendAttachments:
			"This device cannot send message attachments."
		case .unsupportedAttachmentType(let type):
			"The Messages app does not support attachments of type \(type)."
		case .attachmentRejected(let filename):
			"The Messages app could not attach ‘\(filename)’."
		}
	}
}

public struct MessageComposeView: UIViewControllerRepresentable {
	public let message: ComposedMessage
	public let onFinish: (MessageComposeResult) -> Void

	public init(message: ComposedMessage, onFinish: @escaping (MessageComposeResult) -> Void) {
		self.message = message
		self.onFinish = onFinish
	}

	public static var canSendAttachments: Bool {
		MFMessageComposeViewController.canSendAttachments()
	}

	public static var canSendText: Bool {
		MFMessageComposeViewController.canSendText()
	}

	public static func validationError(for message: ComposedMessage) -> MessageComposeError? {
		guard canSendText else { return .cannotSendText }
		guard message.attachments.isEmpty || canSendAttachments else { return .cannotSendAttachments }
		for attachment in message.attachments {
			let identifier = attachment.content.contentType.identifier
			guard MFMessageComposeViewController.isSupportedAttachmentUTI(identifier) else {
				return .unsupportedAttachmentType(identifier)
			}
		}
		return nil
	}

	public func makeCoordinator() -> Coordinator {
		Coordinator(onFinish: onFinish)
	}

	public func makeUIViewController(context: Context) -> MFMessageComposeViewController {
		let compose = MFMessageComposeViewController()
		compose.messageComposeDelegate = context.coordinator
		compose.recipients = message.recipients.isEmpty ? nil : message.recipients
		compose.body = message.body

		if Self.validationError(for: message) == nil {
			for attachment in message.attachments {
				let accepted = compose.addAttachmentData(
					attachment.content.data,
					typeIdentifier: attachment.content.contentType.identifier,
					filename: attachment.filename
				)
				if !accepted {
					assertionFailure(MessageComposeError.attachmentRejected(attachment.filename).localizedDescription)
				}
			}
		}

		return compose
	}

	public func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

	public static func dismantleUIViewController(_ uiViewController: MFMessageComposeViewController, coordinator: Coordinator) {
		uiViewController.messageComposeDelegate = nil
	}

	@MainActor
	public final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
		private let onFinish: (MessageComposeResult) -> Void

		init(onFinish: @escaping (MessageComposeResult) -> Void) {
			self.onFinish = onFinish
		}

		@MainActor
		public func messageComposeViewController(
			_ controller: MFMessageComposeViewController,
			didFinishWith result: MessageComposeResult
		) {
			controller.dismiss(animated: true) {
				self.onFinish(result)
			}
		}
	}
}
#endif
