#if !os(tvOS) && !os(watchOS)
import SwiftUI
#if canImport(UIKit)
import UIKit

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
#elseif canImport(AppKit)
import AppKit

/// macOS document export: a save panel for one file, a folder panel for several.
public struct DocumentExportView: NSViewRepresentable {
    let urls: [URL]
    let asCopy: Bool

    public init(urls: [URL], asCopy: Bool = true) {
        self.urls = urls
        self.asCopy = asCopy
    }

    public func makeNSView(context: Context) -> NSView {
        let view = SBJPanelAnchor()
        let urls = urls
        let asCopy = asCopy
        DispatchQueue.main.async { [weak view] in
            guard let view, view.window != nil, !urls.isEmpty else { return }
            if urls.count == 1, let source = urls.first {
                let panel = NSSavePanel()
                panel.nameFieldStringValue = source.lastPathComponent
                panel.canCreateDirectories = true
                panel.begin { response in
                    guard response == .OK, let destination = panel.url, destination != source else { return }
                    do {
                        if asCopy { try FileManager.default.copyItem(at: source, to: destination) }
                        else { try FileManager.default.moveItem(at: source, to: destination) }
                    } catch { NSLog("Document export failed: %@", error.localizedDescription) }
                }
            } else {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.canCreateDirectories = true
                panel.begin { response in
                    guard response == .OK, let directory = panel.url else { return }
                    for source in urls {
                        let destination = directory.appendingPathComponent(source.lastPathComponent)
                        guard destination != source else { continue }
                        do {
                            if asCopy { try FileManager.default.copyItem(at: source, to: destination) }
                            else { try FileManager.default.moveItem(at: source, to: destination) }
                        } catch { NSLog("Document export failed: %@", error.localizedDescription) }
                    }
                }
            }
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
#endif
