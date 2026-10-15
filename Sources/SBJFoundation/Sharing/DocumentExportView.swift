#if !os(tvOS) && !os(watchOS)
import SwiftUI
import UIKit
import SBJShared

public typealias ExportPayload = Identified<[URL]>

public struct DocumentExportView: UIViewControllerRepresentable {
	let urls: [URL]
	let asCopy: Bool

	public init(urls: [URL], asCopy: Bool = true) {
		self.urls = urls
		self.asCopy = asCopy
	}

	public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
		UIDocumentPickerViewController(forExporting: urls, asCopy: asCopy)
	}

	public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
	}
}



#endif
