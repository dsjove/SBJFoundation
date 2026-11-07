#if !os(watchOS) && (canImport(UIKit) || canImport(AppKit))
import SBJLocalization
import Observation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import UniformTypeIdentifiers
import ImageIO
#if !os(tvOS)
import PhotosUI
#endif
import SBJCamera
import SBJFileResources
import SBJDataDefinition
import SBJDocuments
import SBJUIVocabulary
import SBJSharing

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
    var resourceLoadError: String?
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
    private let source: SBJResourceSource?

    /// Known absence suppresses read actions; unknown permits an attempt.
    private var canAcquireResource: Bool {
        if let source { return source.hasContent != false }
        return resource != nil
    }

    @MainActor
    private func acquireResource() async -> SBJResourceContent? {
        do {
            return try await source?.resolve() ?? resource
        } catch {
            state.resourceLoadError = error.localizedDescription
            return nil
        }
    }

    @MainActor
    private func saveResource(_ value: SBJResourceContent?) async {
        guard let source else {
            resource = value
            return
        }
        do {
            try await source.save(value)
        } catch {
            state.resourceLoadError = error.localizedDescription
        }
    }

    @MainActor
    private func viewAcquiredResource() {
        Task { @MainActor in
            guard let acquired = await acquireResource(), !Task.isCancelled else { return }
            state.viewingResource = acquired
        }
    }

    @MainActor
    private func editAcquiredResource() {
        Task { @MainActor in
            guard let acquired = await acquireResource(), !Task.isCancelled else { return }
            beginEditing(acquired, restoringOnCancel: false)
        }
    }

    private let viewerTitle: String?
    private let editImports: Bool
    private let editorOptions: PhotoEditorOptions
    private let label: () -> Content

    // Original binding-based API remains unchanged.
    public init(
        resource: Binding<SBJResourceContent?>,
        options: PhotoMenuOptions = .all,
        viewerTitle: String? = nil,
        editImports: Bool = true,
        editorOptions: PhotoEditorOptions = .default
    ) where Content == _DefaultPhotoMenuLabel {
        self._resource = resource
        self.source = nil
        self.options = options
        self.viewerTitle = viewerTitle
        self.editImports = editImports
        self.editorOptions = editorOptions
        self.label = { _DefaultPhotoMenuLabel(isFilled: resource.wrappedValue != nil) }
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
        self.source = nil
        self.options = options
        self.viewerTitle = viewerTitle
        self.editImports = editImports
        self.editorOptions = editorOptions
        self.label = label
    }

    // Async-binding API: identical options; source replaces the binding.
    public init(
        source: SBJResourceSource,
        options: PhotoMenuOptions = .all,
        viewerTitle: String? = nil,
        editImports: Bool = true,
        editorOptions: PhotoEditorOptions = .default
    ) where Content == _DefaultPhotoMenuLabel {
        self._resource = .constant(nil)
        self.source = source
        self.options = options
        self.viewerTitle = viewerTitle
        self.editImports = editImports
        self.editorOptions = editorOptions
        self.label = { _DefaultPhotoMenuLabel(isFilled: source.hasContent == true) }
    }

    public init(
        source: SBJResourceSource,
        options: PhotoMenuOptions = .modify,
        viewerTitle: String? = nil,
        editImports: Bool = true,
        editorOptions: PhotoEditorOptions = .default,
        @ViewBuilder label: @escaping () -> Content
    ) {
        self._resource = .constant(nil)
        self.source = source
        self.options = options
        self.viewerTitle = viewerTitle
        self.editImports = editImports
        self.editorOptions = editorOptions
        self.label = label
    }

#if !os(tvOS)
    @ViewBuilder
    private func menuItems(_ labelIsHidden: Bool, sharePresenter: SBJSharePresenter) -> some View {
        if options.contains(.view), canAcquireResource {
            menuButton("View", labeled: !labelIsHidden, image: SBJImageSymbology.viewPhoto) {
                viewAcquiredResource()
            }
        }

        if options.contains(.share), canAcquireResource {
            menuButton("Share", labeled: !labelIsHidden, image: SBJSymbology.share) {
                Task { @MainActor in
                    guard let acquired = await acquireResource(),
                          let image = acquired.sbjImage, !Task.isCancelled else { return }
                    sharePresenter.present(SBJSharePayload(image))
                }
            }
        }

        if options.contains(.photos), PhotoMenuOptions.canShowPhotos {
            menuButton("Photos", labeled: !labelIsHidden, image: SBJImageSymbology.choosePhotos) {
                state.isPhotoPickerPresented = true
            }
        }

        if options.contains(.camera), PhotoMenuOptions.canShowCamera {
            menuButton("Camera", labeled: !labelIsHidden, image: SBJImageSymbology.camera) {
                state.isCameraPresented = true
            }
        }

        if options.contains(.files), PhotoMenuOptions.canShowFiles {
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

        if options.contains(.edit), canAcquireResource {
            menuButton("Edit", labeled: !labelIsHidden, image: SBJImageSymbology.editPhoto) {
                editAcquiredResource()
            }
        }

        if options.contains(.clear), canAcquireResource {
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
            .photoModal(
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
            .photoModal(
                isPresented: Binding(
                    get: { state.editingResource != nil },
                    set: { if !$0 { finishEditing(with: nil) } }
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
            .photoModal(isPresented: $state.isCameraPresented) {
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
            .alert("Unable to Load Photo", isPresented: Binding(
                get: { state.resourceLoadError != nil },
                set: { if !$0 { state.resourceLoadError = nil } }
            )) {
                Button("OK") { state.resourceLoadError = nil }
            } message: {
                Text(state.resourceLoadError ?? "Unknown error")
            }
            .alert("Clear Photo", isPresented: $state.isPhotoClearPresented) {
                Button("Clear", role: .destructive) {
                    Task { await saveResource(nil) }
                }
                Button("Cancel", role: .cancel) { }
            }
    }

    @MainActor
    private func refreshPasteAvailability() {
        #if canImport(UIKit)
        state.canPasteImage = UIPasteboard.general.hasImages
        #else
        state.canPasteImage = NSPasteboard.general.canReadItem(
            withDataConformingToTypes: [UTType.image.identifier]
        ) || NSImage(pasteboard: .general) != nil
        #endif
    }

    @MainActor
    private func importFromPasteboard() {
        #if canImport(UIKit)
        let pasteboard = UIPasteboard.general
        for identifier in pasteboard.types {
            guard let type = UTType(identifier), type.conforms(to: .image),
                  let data = pasteboard.data(forPasteboardType: identifier) else { continue }
            acceptImported(.init(data: data, contentType: type))
            return
        }
        guard let image = pasteboard.image else { return }
        #else
        let pasteboard = NSPasteboard.general
        for item in pasteboard.pasteboardItems ?? [] {
            for identifier in item.types {
                guard let type = UTType(identifier.rawValue), type.conforms(to: .image),
                      let data = item.data(forType: identifier) else { continue }
                acceptImported(.init(data: data, contentType: type))
                return
            }
        }
        guard let image = NSImage(pasteboard: pasteboard) else { return }
        #endif
        Task { await importNativeImage(image) }
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
    private func importNativeImage(_ image: SBJImage) async {
        guard let imported = await PhotoResourceEncoding.encode(image) else { return }
        acceptImported(imported)
    }

    @MainActor
    private func acceptImported(_ imported: SBJResourceContent) {
        // The binding is authoritative about storage representation. Assign first,
        // then read it back: a model that requires complete image documents can
        // normalize the value in its Binding setter, while ordinary models simply
        // retain the imported JPEG/PNG/HEIC.
        if source != nil {
            if editImports {
                // Editing a new import is transactional for an async source:
                // cancel leaves its persisted content unchanged.
                beginEditing(imported, restoringOnCancel: false, allowsUnchangedCompletion: true)
            } else {
                Task { await saveResource(imported) }
            }
            return
        }
        let previous = resource
        resource = imported
        guard let stored = resource else { return }
        if editImports {
            state.resourceBeforeImportedEdit = previous
            beginEditing(stored, restoringOnCancel: true)
        }
    }

    @MainActor
    private func beginEditing(
        _ value: SBJResourceContent,
        restoringOnCancel: Bool,
        allowsUnchangedCompletion: Bool = false
    ) {
        state.restoresResourceOnEditCancel = restoringOnCancel
        state.allowsUnchangedEditCompletion = restoringOnCancel || allowsUnchangedCompletion
        if !restoringOnCancel {
            state.resourceBeforeImportedEdit = nil
        }
        state.editingResource = value
    }

    @MainActor
    private func finishEditing(with result: SBJResourceContent?) {
        if let result {
            if source != nil {
                Task { await saveResource(result) }
            } else {
                resource = result
            }
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
            if options.contains(.clear), canAcquireResource {
                Button(role: .destructive) {
                    state.isPhotoClearPresented = true
                } label: {
                    Label("Clear", symbol: SBJSymbology.delete)
                }
            }
        } label: {
            label()
        }
        .disabled(!canAcquireResource || !options.contains(.clear))
        .alert("Clear Photo", isPresented: Binding(
            get: { state.isPhotoClearPresented },
            set: { state.isPhotoClearPresented = $0 }
        )) {
            Button("Clear", role: .destructive) {
                Task { await saveResource(nil) }
            }
            Button("Cancel", role: .cancel) { }
        }
#else
        SBJSharePresentationHost { sharePresenter in
            actions(
                content: Group {
                    if source != nil {
                        // Deferred sources expose a stable menu; avoid the
                        // single-action collapsing behavior during async updates.
                        Menu {
                            menuItems(false, sharePresenter: sharePresenter)
                        } label: {
                            label()
                        }
                    } else {
                        // Preserve the original binding-based presentation.
                        SBJSelectionMenu {
                            menuItems(false, sharePresenter: sharePresenter)
                        } collapsedContent: {
                            menuItems(true, sharePresenter: sharePresenter)
                        } label: {
                            label()
                        }
                    }
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
/// Non-generic encoding boundary; one ImageIO implementation for AppKit and UIKit.
private enum PhotoResourceEncoding {
    private struct SendableImageBox: @unchecked Sendable {
        let image: SBJImage
    }

    @MainActor
    static func encode(_ image: SBJImage) async -> SBJResourceContent? {
        let box = SendableImageBox(image: image)
        return await Task.detached(priority: .userInitiated) {
            guard let cg = box.image.sbjCGImage else { return nil }
            let alpha = cg.alphaInfo
            let hasAlpha: Bool = {
                switch alpha {
                case .first, .last, .premultipliedFirst, .premultipliedLast: true
                default: false
                }
            }()
            let type: UTType = hasAlpha ? .png : .jpeg
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                output, type.identifier as CFString, 1, nil
            ) else { return nil }
            CGImageDestinationAddImage(destination, cg, [
                kCGImageDestinationLossyCompressionQuality: 0.92
            ] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { return nil }
            return SBJResourceContent(data: output as Data, contentType: type)
        }.value
    }
}
#endif
#endif

#if os(macOS) || os(iOS) || os(visionOS)
private struct PhotoModalModifier<Presented: View>: ViewModifier {
    @Binding var isPresented: Bool
    let content: () -> Presented

    func body(content base: Content) -> some View {
        #if os(macOS)
        base.sheet(isPresented: $isPresented, content: content)
        #else
        base.fullScreenCover(isPresented: $isPresented, content: content)
        #endif
    }
}

private extension View {
    func photoModal<Presented: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Presented
    ) -> some View {
        modifier(PhotoModalModifier(isPresented: isPresented, content: content))
    }
}
#endif
