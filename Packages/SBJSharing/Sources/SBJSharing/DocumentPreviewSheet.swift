#if (canImport(QuickLook) && canImport(UIKit) && !os(visionOS)) || (os(macOS) && canImport(QuickLookUI))
import SwiftUI
#if canImport(UIKit)
import QuickLook
import UIKit
#elseif canImport(QuickLookUI)
import QuickLookUI
import AppKit
#endif
import SBJLocalization
import SBJFileResources
import SBJUIVocabulary

public struct DocumentPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    public let url: URL
    public let displayName: String

    public init(url: URL, displayName: String) {
        self.url = url
        self.displayName = displayName
    }

    @ViewBuilder
    private var previewContent: some View {
        #if os(macOS)
        SBJMacDocumentPreview(url: url)
        #else
        AttachmentPreviewSheet(url: url, displayName: displayName)
        #endif
    }

    public var body: some View {
        SBJSharePresentationHost { sharePresenter in
            NavigationStack {
                previewContent
                    .navigationTitle(displayName)
                    .modifier(SBJPreviewTitleStyle())
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { dismiss() }
                                .keyboardShortcut(.cancelAction)
                        }

                        ToolbarItemGroup(placement: .primaryAction) {
                            SBJSymbolButton(
                                SBJSymbology.open,
                                accessibilityLabel: "Open"
                            ) {
                                url.open()
                            }

                            SBJShareButton(
                                presenter: sharePresenter,
                                prepare: { SBJSharePayload(url) }
                            ) {
                                Image(symbol: SBJSymbology.share)
                                    .accessibilityLabel("Share")
                            }
                        }
                    }
            }
            .interactiveDismissDisabled()
        }
    }
}
private struct SBJPreviewTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content
        #else
        content.navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#if os(macOS)
private struct SBJMacDocumentPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
#if os(macOS)
		if let view = QLPreviewView(frame: .zero, style: .normal) {
			view.previewItem = url as NSURL
			return view
		}
		return QLPreviewView()
#else
        let view = QLPreviewView(frame: .zero, style: .normal)
        view.previewItem = url as NSURL
        return view
#endif
    }

    func updateNSView(_ view: QLPreviewView, context: Context) {
        view.previewItem = url as NSURL
    }
}
#endif
#endif
