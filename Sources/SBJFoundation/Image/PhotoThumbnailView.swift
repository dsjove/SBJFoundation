#if !os(watchOS) && canImport(UIKit)
import SwiftUI
import SBJFileResources

/// Compact image-resource control suitable for lists, inspectors, and editor rows.
///
/// This captures the useful behavior of the former model-bound photo thumbnail
/// control without requiring models to persist `UIImage` values or a duplicate
/// thumbnail payload. The caller supplies the resource-content binding owned by
/// its resource store.
@MainActor
public struct PhotoThumbnailView: View {
    @Binding private var resource: SBJResourceContent?

    private let options: PhotoMenuOptions
    private let viewerTitle: String?
    private let editImports: Bool
    private let editorOptions: PhotoEditorOptions
    private let placeholder: ImageReference
    private let showsPreview: Bool
    private let size: CGSize

    public init(
        resource: Binding<SBJResourceContent?>,
        options: PhotoMenuOptions = .all,
        viewerTitle: String? = nil,
        editImports: Bool = true,
        editorOptions: PhotoEditorOptions = .default,
        placeholder: ImageReference = .symbol(SBJImageSymbology.photo),
        showsPreview: Bool = true,
        size: CGSize = .init(width: 44, height: 44)
    ) {
        self._resource = resource
        self.options = options
        self.viewerTitle = viewerTitle
        self.editImports = editImports
        self.editorOptions = editorOptions
        self.placeholder = placeholder
        self.showsPreview = showsPreview
        self.size = size
    }

    public var body: some View {
        PhotoMenu(
            resource: $resource,
            options: options,
            viewerTitle: viewerTitle,
            editImports: editImports,
            editorOptions: editorOptions
        ) {
            thumbnail
                .sbjActiveControl(
                    horizontalPadding: 3,
                    verticalPadding: 3
                )
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if showsPreview, let image = resource?.uiImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .clipped()
        } else if resource != nil {
            Image(symbol: SBJImageSymbology.photoFilled)
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.secondary)
        } else if !placeholder.isEmpty {
            Image(placeholder)
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.secondary)
        }
    }
}

/// Display-only rendering for image resource content with a semantic placeholder.
@MainActor
public struct PhotoDisplayView: View {
    private let resource: SBJResourceContent?
    private let placeholder: ImageReference
    private let cornerRadius: CGFloat

    public init(
        resource: SBJResourceContent?,
        placeholder: ImageReference = .symbol(SBJImageSymbology.photo),
        cornerRadius: CGFloat = 12
    ) {
        self.resource = resource
        self.placeholder = placeholder
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        if let image = resource?.uiImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .frame(alignment: .center)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .clipped()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.secondary.opacity(0.1))

                if !placeholder.isEmpty {
                    Image(placeholder)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .frame(alignment: .center)
        }
    }
}
#endif
