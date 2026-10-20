import SBJUIVocabulary
import SBJCamera
import SBJDataDefinition
import SBJDocuments
import SBJFileResources
#if !os(watchOS) && canImport(UIKit)
import SwiftUI
import UIKit
import Observation
import UniformTypeIdentifiers
#if !os(tvOS)
import PhotosUI
#endif
import SBJLocalization

public struct _DefaultPhotoMenuLabel: View {
    let isFilled: Bool
    public var body: some View {
        Image(symbol: isFilled ? SBJImageSymbology.photoFilled : SBJImageSymbology.photo)
            .controlSize(.regular)
            .buttonStyle(.borderedProminent)
            .accessibilityAddTraits(.isButton)
    }
}

@MainActor
@Observable
private final class PhotoMenuState {
    var isPhotoPickerPresented = false
#if !os(tvOS)
    var photoPickerSelection: PhotosPickerItem?
#endif
    var isCameraPresented = false
    var isFileImporterPresented = false
    var isPhotoClearPresented = false
    var canPasteImage = false
    var viewingResource: SBJResourceContent?
    var editingResource: SBJResourceContent?
    var resourceBeforeImportedEdit: SBJResourceContent?
    var restoresResourceOnEditCancel = false
    var allowsUnchangedEditCompletion = false
}

/// Imports and manages image resource content without making `UIImage` the
/// persisted/editable value.
///
/// Files, Photos and Paste preserve encoded bytes and their UTType whenever
/// possible. Camera images are encoded away from the main actor before being
/// returned through the binding.
///
/// Edit behavior follows the resource itself: an `SBJImageDocument` is reopened
/// with its saved geometry/color/markup, while an ordinary image is edited
/// destructively in memory. Applications choose persistence semantics by what
/// their resource binding stores; `PhotoMenu` has no separate preservation flag.
public struct PhotoMenu<Content: View>: View {
    @Binding private var resource: SBJResourceContent?
    @Environment(\.presentationChromeSuppression) private var presentationChromeSuppression
    @State private var state = PhotoMenuState()
    @State private var isSuppressingPresentationChrome = false

    private let options: PhotoMenuOptions
    private let viewerTitle: String?
    private let editImports: Bool
    private let editorOptions: PhotoEditorOptions
    private let label: () -> Content

    public init(
        resource: Binding<SBJResourceContent?>,
        options: PhotoMenuOptions = .all,
        viewerTitle: String? = nil,
        editImports: Bool = true,
        editorOptions: PhotoEditorOptions = .default
    ) where Content == _DefaultPhotoMenuLabel {
        self._resource = resource
        self.options = options
        self.viewerTitle = viewerTitle
        self.editImports = editImports
        self.editorOptions = editorOptions
        self.label = {
            _DefaultPhotoMenuLabel(isFilled: resource.wrappedValue != nil)
        }
    }

    public init(
        resource: Binding<SBJResourceContent?>,
        options: PhotoMenuOptions = .modify,
        viewerTitle: String? = nil,
        editImports: Bool = true,
        editorOptions: PhotoEditorOptions = .default,
        @ViewBuilder label: @escaping () -> Content
    ) {
        self._resource = resource
        self.options = options
        self.viewerTitle = viewerTitle
        self.editImports = editImports
        self.editorOptions = editorOptions
        self.label = label
    }

#if !os(tvOS)
    @MainActor
    private var image: UIImage? {
        resource?.uiImage
    }

    @ViewBuilder
    private func menuItems(_ labelIsHidden: Bool, sharePresenter: SBJSharePresenter) -> some View {
        if options.contains(.view), resource != nil {
            menuButton("View", labeled: !labelIsHidden, image: SBJImageSymbology.viewPhoto) {
                state.viewingResource = resource
            }
        }

        if options.contains(.share), let image {
            SBJShareButton(
                presenter: sharePresenter,
                prepare: { SBJSharePayload(image) }
            ) {
                if !labelIsHidden {
                    Label("Share", symbol: SBJSymbology.share)
                } else {
                    Image(symbol: SBJSymbology.share)
                        .accessibilityLabel("Share")
                }
            }
        }

        if options.contains(.photos) {
            menuButton("Photos", labeled: !labelIsHidden, image: SBJImageSymbology.choosePhotos) {
                state.isPhotoPickerPresented = true
            }
        }

        if options.contains(.camera), PhotoMenuOptions.canShowCamera {
            menuButton("Camera", labeled: !labelIsHidden, image: SBJImageSymbology.camera) {
                state.isCameraPresented = true
            }
        }

        if options.contains(.files) {
            menuButton("Files", labeled: !labelIsHidden, image: SBJImageSymbology.chooseFile) {
                state.isFileImporterPresented = true
            }
        }

        if options.contains(.paste) {
            menuButton("Paste", labeled: !labelIsHidden, image: SBJImageSymbology.pastePhoto) {
                importFromPasteboard()
            }
            .disabled(!state.canPasteImage)
        }

        if options.contains(.edit), let resource {
            menuButton("Edit", labeled: !labelIsHidden, image: SBJImageSymbology.editPhoto) {
                beginEditing(resource, restoringOnCancel: false)
            }
        }

        if options.contains(.clear), resource != nil {
            Button(role: .destructive) {
                state.isPhotoClearPresented = true
            } label: {
                Label("Clear", symbol: SBJSymbology.delete)
            }
        }
    }

    @ViewBuilder
    private func menuButton(
        _ title: LocalizedStringKey,
        labeled: Bool,
        image: SBJSymbol,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        Button(action: action) {
            if labeled {
                Label(title, symbol: image)
            } else {
                Image(symbol: image)
                    .accessibilityLabel(title)
            }
        }
    }

    @ViewBuilder
    private func actions(content: some View) -> some View {
        @Bindable var state = state
        content
            // Intentional polling: pasteboard availability can remain stale on
            // some supported systems when queried only at presentation time.
            .task {
                while !Task.isCancelled {
                    refreshPasteAvailability()
                    do {
                        try await Task.sleep(for: .seconds(1))
                    } catch {
                        return
                    }
                }
            }
            .photosPicker(
                isPresented: $state.isPhotoPickerPresented,
                selection: $state.photoPickerSelection,
                matching: .images
            )
            .onChange(of: state.photoPickerSelection) { _, item in
                guard let item else { return }
                state.photoPickerSelection = nil
                Task { await importPhotoPickerItem(item) }
            }
            .fullScreenCover(
                isPresented: Binding(
                    get: { state.viewingResource != nil },
                    set: { if !$0 { state.viewingResource = nil } }
                )
            ) {
                if let viewingResource = state.viewingResource,
                   let viewer = PhotoViewer(resource: viewingResource, title: viewerTitle) {
                    viewer
                }
            }
            .fullScreenCover(
                isPresented: Binding(
                    get: { state.editingResource != nil },
                    set: { if !$0 { state.editingResource = nil } }
                )
            ) {
                if let editingResource = state.editingResource {
                    if let document = imageDocument(from: editingResource),
                       let editor = PhotoEditor(
                        document: document,
                        title: viewerTitle,
                        options: editorOptions,
                        allowsUnchangedCompletion: state.allowsUnchangedEditCompletion,
                        onComplete: { result in
                            finishEditing(with: result?.resourceContent())
                        }
                       ) {
                        editor
                    } else if let editor = PhotoEditor(
                        resource: editingResource,
                        title: viewerTitle,
                        options: editorOptions,
                        allowsUnchangedCompletion: state.allowsUnchangedEditCompletion,
                        onComplete: { result in
                            finishEditing(with: result)
                        }
                    ) {
                        editor
                    }
                }
            }
            .fullScreenCover(isPresented: $state.isCameraPresented) {
                CameraView { attachment in
                    state.isCameraPresented = false
                    guard let attachment,
                          let contentType = UTType(attachment.utiType) else { return }
                    acceptImported(.init(data: attachment.blob, contentType: contentType))
                }
            }
            .fileImporter(
                isPresented: $state.isFileImporterPresented,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                guard case .success(let urls) = result, let url = urls.first else { return }
                Task { await importFile(url) }
            }
            .alert("Clear Photo", isPresented: $state.isPhotoClearPresented) {
                Button("Clear", role: .destructive) {
                    resource = nil
                }
                Button("Cancel", role: .cancel) { }
            }
    }

    @MainActor
    private func refreshPasteAvailability() {
        state.canPasteImage = UIPasteboard.general.hasImages
    }

    @MainActor
    private func importFromPasteboard() {
        let pasteboard = UIPasteboard.general

        for typeIdentifier in pasteboard.types {
            let type = UTType(typeIdentifier)
            guard type?.conforms(to: .image) == true,
                  let data = pasteboard.data(forPasteboardType: typeIdentifier),
                  let type else { continue }
            acceptImported(.init(data: data, contentType: type))
            return
        }

        // Some systems expose an image but not a directly retrievable encoded
        // representation. Fall back to off-main encoding in that case.
        guard let image = pasteboard.image else { return }
        Task { await importUIImage(image) }
    }

    @MainActor
    private func importPhotoPickerItem(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let type = item.supportedContentTypes.first(where: { $0.conforms(to: .image) }) ?? .image
        acceptImported(.init(data: data, contentType: type))
    }

    @MainActor
    private func importFile(_ url: URL) async {
        guard let imported = await Self.readImageResource(at: url) else { return }
        acceptImported(imported)
    }

    @MainActor
    private func importUIImage(_ image: UIImage) async {
        guard let imported = await PhotoResourceEncoding.encode(image) else { return }
        acceptImported(imported)
    }

    @MainActor
    private func acceptImported(_ imported: SBJResourceContent) {
        // The binding is authoritative about storage representation. Assign first,
        // then read it back: a model that requires complete image documents can
        // normalize the value in its Binding setter, while ordinary models simply
        // retain the imported JPEG/PNG/HEIC.
        let previous = resource
        resource = imported
        guard let stored = resource else { return }

        if editImports {
            state.resourceBeforeImportedEdit = previous
            beginEditing(stored, restoringOnCancel: true)
        }
    }

    @MainActor
    private func beginEditing(_ value: SBJResourceContent, restoringOnCancel: Bool) {
        state.restoresResourceOnEditCancel = restoringOnCancel
        state.allowsUnchangedEditCompletion = restoringOnCancel
        if !restoringOnCancel {
            state.resourceBeforeImportedEdit = nil
        }
        state.editingResource = value
    }

    @MainActor
    private func finishEditing(with result: SBJResourceContent?) {
        if let result {
            resource = result
        } else if state.restoresResourceOnEditCancel {
            resource = state.resourceBeforeImportedEdit
        }

        state.restoresResourceOnEditCancel = false
        state.allowsUnchangedEditCompletion = false
        state.resourceBeforeImportedEdit = nil
        state.editingResource = nil
    }

    private func imageDocument(from resource: SBJResourceContent) -> SBJImageDocument? {
        return try? SBJImageDocument(resourceContent: resource)
    }

    private nonisolated static func readImageResource(at url: URL) async -> SBJResourceContent? {
        await Task.detached(priority: .userInitiated) {
            url.withSecurityScopedAccess { scopedURL in
                var coordinatedError: NSError?
                var imported: SBJResourceContent?
                let coordinator = NSFileCoordinator()
                coordinator.coordinate(readingItemAt: scopedURL, options: [], error: &coordinatedError) { coordinatedURL in
                    guard let data = try? Data(contentsOf: coordinatedURL) else { return }
                    let type = (try? coordinatedURL.resourceValues(forKeys: [.contentTypeKey]).contentType)
                        ?? UTType(filenameExtension: coordinatedURL.pathExtension)
                    guard let type, type.conforms(to: .image) else { return }
                    imported = .init(data: data, contentType: type)
                }
                guard coordinatedError == nil else { return nil }
                return imported
            }
        }.value
    }

    /// Parent editor actions should not remain exposed while PhotoMenu owns a
    /// modal presentation. This intentionally includes sheets, pickers and alerts,
    /// not just the camera: parent actions should never act through child UI.
    private var suppressesPresentationChrome: Bool {
        state.isPhotoPickerPresented
        || state.isCameraPresented
        || state.isFileImporterPresented
        || state.isPhotoClearPresented
        || state.viewingResource != nil
        || state.editingResource != nil
    }

    @MainActor
    private func updatePresentationChromeSuppression(_ shouldSuppress: Bool) {
        guard shouldSuppress != isSuppressingPresentationChrome else { return }
        isSuppressingPresentationChrome = shouldSuppress
        if shouldSuppress {
            presentationChromeSuppression.begin()
        } else {
            presentationChromeSuppression.end()
        }
    }

#endif

    public var body: some View {
#if os(tvOS)
        Menu {
            if options.contains(.clear), resource != nil {
                Button(role: .destructive) {
                    state.isPhotoClearPresented = true
                } label: {
                    Label("Clear", symbol: SBJSymbology.delete)
                }
            }
        } label: {
            label()
        }
        .disabled(resource == nil || !options.contains(.clear))
        .alert("Clear Photo", isPresented: Binding(
            get: { state.isPhotoClearPresented },
            set: { state.isPhotoClearPresented = $0 }
        )) {
            Button("Clear", role: .destructive) { resource = nil }
            Button("Cancel", role: .cancel) { }
        }
#else
        SBJSharePresentationHost { sharePresenter in
            actions(
                content: SBJSelectionMenu {
                    menuItems(false, sharePresenter: sharePresenter)
                } collapsedContent: {
                    menuItems(true, sharePresenter: sharePresenter)
                } label: {
                    label()
                }
                .menuStyle(.button)
            )
            .onChange(of: suppressesPresentationChrome, initial: true) { _, shouldSuppress in
                updatePresentationChromeSuppression(shouldSuppress)
            }
            .onDisappear {
                // Balance an outstanding begin() if this menu leaves the hierarchy
                // while one of its child presentations is active.
                updatePresentationChromeSuppression(false)
            }
        }
#endif
    }
}

#if !os(tvOS)
/// Non-generic encoding boundary so detached work does not capture
/// `PhotoMenu<Content>.Type` (which triggers Swift 6 Sendable-metatype diagnostics).
private enum PhotoResourceEncoding {
    private struct SendableImageBox: @unchecked Sendable {
        let image: UIImage
    }

    @MainActor
    static func encode(_ image: UIImage) async -> SBJResourceContent? {
        let box = SendableImageBox(image: image)
        return await Task.detached(priority: .userInitiated) {
            let hasAlpha: Bool = {
                guard let alphaInfo = box.image.cgImage?.alphaInfo else { return false }
                switch alphaInfo {
                case .first, .last, .premultipliedFirst, .premultipliedLast:
                    return true
                default:
                    return false
                }
            }()

            if hasAlpha, let data = box.image.pngData() {
                return .init(data: data, contentType: .png)
            }
            if let data = box.image.jpegData(compressionQuality: 0.92) {
                return .init(data: data, contentType: .jpeg)
            }
            if let data = box.image.pngData() {
                return .init(data: data, contentType: .png)
            }
            return nil
        }.value
    }
}
#endif
#endif
