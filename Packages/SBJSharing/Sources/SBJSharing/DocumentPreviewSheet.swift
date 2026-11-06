#if (canImport(QuickLook) && canImport(UIKit) && !os(visionOS)) || (os(macOS) && canImport(QuickLookUI))
import SwiftUI
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

    public var body: some View {
        SBJSharePresentationHost { sharePresenter in
            NavigationStack {
                AttachmentPreviewSheet(url: url, displayName: displayName)
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

#endif
