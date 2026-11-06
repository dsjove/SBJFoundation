#if !os(watchOS) && !os(tvOS) && (canImport(UIKit) || canImport(AppKit))
import SBJLocalization
import Observation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import SBJFileResources
import SBJDataDefinition
import SBJDocuments
import SBJUIVocabulary
import SBJHelp
import SBJSharing

public extension SBJBundledContentReference {
    static var imageViewHelp: SBJBundledContentReference {
        .help("Image View", bundle: .module)
    }
}

/// Full-screen presentation for inspecting image resource content.
///
/// The viewer intentionally owns only presentation transforms (zoom and pan).
/// Keeping those transforms separate from the encoded resource gives the future
/// editor a place to add persistent transforms such as crop, rotation, mirror,
/// and markup without changing the viewer's presentation contract.
@MainActor
public struct PhotoViewer: View {
    private let resource: SBJResourceContent
    private let image: SBJImage
    private let title: String?

    @Environment(\.dismiss) private var dismiss
    @State private var transform: PhotoViewerTransform

    public init?(
        resource: SBJResourceContent,
        title: String? = nil,
        maximumScale: CGFloat = 8
    ) {
        let image: SBJImage?
        if let document = try? SBJImageDocument(resourceContent: resource) {
            image = document.renderedImage(renderIfNeeded: true)
        } else {
            image = resource.sbjImage
        }

        guard let image else { return nil }
        self.resource = resource
        self.image = image
        self.title = title
        self._transform = State(initialValue: PhotoViewerTransform(
            sourceSize: image.size,
            maximumScale: maximumScale
        ))
    }

    public var body: some View {
        SBJSharePresentationHost { sharePresenter in
            NavigationStack {
                GeometryReader { geometry in
                    ZStack {
                        Color.black
                            .ignoresSafeArea()

                        image.sbjSwiftUIImage
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(
                                width: transform.fittedSize.width,
                                height: transform.fittedSize.height
                            )
                            .scaleEffect(transform.scale)
                            .offset(transform.offset)
                            .contentShape(Rectangle())
                            .gesture(transformGesture)
                            .simultaneousGesture(
                                TapGesture(count: 2)
                                    .onEnded { resetPosition() }
                            )
                            .accessibility(AccessibleItem(
                                label: "Photo",
                                hint: "Pinch to zoom, drag to move the photo, or double-tap to reset its position."
                            ))
                    }
                    .clipped()
                    .onChange(of: geometry.size, initial: true) { _, newSize in
                        transform.containerSize = newSize
                    }
                }
                .navigationTitle(title ?? "")
                #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItemGroup(placement: leadingToolbarPlacement) {
                        SBJDismissButton(accessibilityLabel: "Close") {
                            dismiss()
                        }

                        SBJShareButton(
                            presenter: sharePresenter,
                            prepare: { SBJSharePayload(imageForSharing()) }
                        ) {
                            Image(symbol: SBJSymbology.share)
                                .accessibility(AccessibleItem(label: "Share"))
                        }

                        SBJHelpLink(
                            asset: .imageViewHelp,
                            auto: false,
                            configuration: .imageHelp
                        )
                    }

                    ToolbarItem(placement: trailingToolbarPlacement) {
                        SBJSymbolButton(
                            SBJImageSymbology.resetPanZoom,
                            accessibilityLabel: "Reset zoom and position",
                            accessibilityHint: "Returns the image to its fitted size and centered position.",
                            action: resetPosition
                        )
                        .disabled(transform.isAtRest)
                    }
                }
            }
        }
    }

    private var leadingToolbarPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .automatic
        #else
        .topBarLeading
        #endif
    }

    private var trailingToolbarPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .automatic
        #else
        .topBarTrailing
        #endif
    }

    private var transformGesture: some Gesture {
        SimultaneousGesture(
            DragGesture()
                .onChanged { transform.dragChanged($0.translation) }
                .onEnded { _ in transform.dragEnded() },
            MagnificationGesture()
                .onChanged { transform.magnificationChanged($0) }
                .onEnded { _ in transform.magnificationEnded() }
        )
    }

    private func resetPosition() {
        withAnimation(.easeInOut(duration: 0.2)) {
            transform.resetPosition()
        }
    }

    /// Shares the flattened, fully rendered representation of an image document.
    /// Ordinary image resources are already flattened and can be shared directly.
    private func imageForSharing() -> SBJImage {
        guard let document = try? SBJImageDocument(resourceContent: resource) else { return image }
        return document.renderedImage(renderIfNeeded: true) ?? image
    }
}


#endif
