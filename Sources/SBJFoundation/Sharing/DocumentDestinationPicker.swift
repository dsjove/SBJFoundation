#if !os(tvOS) && !os(watchOS)
import SwiftUI
import SBJDataDefinition
import UIKit

/// Folder picker used by app-controlled exports. Selecting the destination
/// directory first lets the app detect name collisions before writing, instead
/// of relying on provider-specific document-picker overwrite behavior.
public struct DocumentDestinationPicker: UIViewControllerRepresentable {
	let onSelect: (URL) -> Void
	let onCancel: () -> Void

	public init(onSelect: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
		self.onSelect = onSelect
		self.onCancel = onCancel
	}

	public func makeCoordinator() -> Coordinator {
		Coordinator(onSelect: onSelect, onCancel: onCancel)
	}

	public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
		let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
		picker.delegate = context.coordinator
		picker.allowsMultipleSelection = false
		picker.modalPresentationStyle = .formSheet
		return picker
	}

	public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }

	public final class Coordinator: NSObject, UIDocumentPickerDelegate {
		private let onSelect: (URL) -> Void
		private let onCancel: () -> Void

		init(onSelect: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
			self.onSelect = onSelect
			self.onCancel = onCancel
		}

		public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
			guard let url = urls.first else {
				onCancel()
				return
			}
			onSelect(url)
		}

		public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
			onCancel()
		}
	}
}
#endif
