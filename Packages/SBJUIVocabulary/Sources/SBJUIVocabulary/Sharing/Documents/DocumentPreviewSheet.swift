#if (canImport(QuickLook) && canImport(UIKit) && !os(visionOS)) || (os(macOS) && canImport(QuickLookUI))
import SwiftUI
import SBJLocalization
import SBJFileResources

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
                            Button(SBJCommonNomenclature.done.title) { dismiss() }
                                .keyboardShortcut(.cancelAction)
                        }

                        ToolbarItemGroup(placement: .primaryAction) {
                            Button {
                                url.open()
                            } label: {
                                Image(symbol: SBJCommonNomenclature.open.symbol!)
                            }
                            .accessibility(
                                label: SBJCommonNomenclature.open.accessibilityLabel ?? SBJCommonNomenclature.open.title,
                                hint: SBJCommonNomenclature.open.accessibilityHint ?? SBJCommonNomenclature.open.summary
                            )

                            SBJShareButton(
                                SBJCommonNomenclature.share,
                                presenter: sharePresenter,
                                prepare: { SBJSharePayload(url) }
                            ) {
                                Image(symbol: SBJCommonNomenclature.share.symbol!)
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
