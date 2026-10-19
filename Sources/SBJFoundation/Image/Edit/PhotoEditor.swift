#if !os(watchOS) && !os(tvOS) && canImport(UIKit)
import SBJHelp
import Observation
import SBJDataDefinition
import SBJDocuments
import SBJFileResources
import SwiftUI
import UIKit
#if canImport(PencilKit)
import PencilKit
import SBJLocalization
#endif

/// Full-screen image editor backed by normalized edit geometry.
///
/// Persistent edits are represented by PhotoEditGeometry. The SwiftUI canvas
/// and PhotoEditRenderer both resolve that same geometry, so crop/placement,
/// rotation and mirror have one source of truth for presentation and export.
@MainActor
public struct PhotoEditor: View {
    private let resource: SBJResourceContent
    private let image: UIImage
    private let title: String?
    private let options: PhotoEditorOptions
    private let onComplete: ((SBJResourceContent?) -> Void)?
    private let onEditComplete: ((PhotoEditResult?) -> Void)?
    private let initialDisplayName: String
    private let initialDescription: String
    private let initialColorAdjustments: PhotoColorAdjustments
    private let allowsUnchangedCompletion: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var model: PhotoEditorModel
    /// UI preference only; persisted independently from image edit state.
    @AppStorage("SBJFoundation.PhotoEditor.isRotationVisible")
    private var isRotationVisible = false
#if canImport(PencilKit)
    @State private var markup: PhotoMarkupState
    @AppStorage("SBJFoundation.PhotoEditor.markupActive")
    private var markupActive = false
#endif

    public init?(
        resource: SBJResourceContent,
        title: String? = nil,
        options: PhotoEditorOptions = .default,
        allowsUnchangedCompletion: Bool = false,
        onComplete: @escaping (SBJResourceContent?) -> Void
    ) {
        guard let image = resource.uiImage else { return nil }
        self.resource = resource
        self.image = image
        self.title = title
        self.options = options
        self.onComplete = onComplete
        self.onEditComplete = nil
        self.initialDisplayName = ""
        self.initialDescription = ""
        self.initialColorAdjustments = .init()
        self.allowsUnchangedCompletion = allowsUnchangedCompletion

        let initial = PhotoEditGeometry(crop: .init(option: options.effectiveInitialCrop, sourceSize: image.size))
        self._model = State(initialValue: PhotoEditorModel(
            geometry: initial,
            sourceSize: image.size,
            options: options
        ))
#if canImport(PencilKit)
        self._markup = State(initialValue: PhotoMarkupState())
#endif
    }

    /// Edits reusable in-memory state without flattening it. Callers may persist the result
    /// in an `SBJImageDocument` or render it destructively themselves.
    public init?(
        resource: SBJResourceContent,
        edits: PhotoEditResult,
        title: String? = nil,
        options: PhotoEditorOptions = .default,
        allowsUnchangedCompletion: Bool = false,
        onComplete: @escaping (PhotoEditResult?) -> Void
    ) {
        guard let image = resource.uiImage else { return nil }
        self.resource = resource
        self.image = image
        self.title = title
        self.options = options
        self.onComplete = nil
        self.onEditComplete = onComplete
        self.initialDisplayName = edits.displayName
        self.initialDescription = edits.description
        self.initialColorAdjustments = edits.color
        self.allowsUnchangedCompletion = allowsUnchangedCompletion
        self._model = State(initialValue: PhotoEditorModel(
            geometry: edits.geometry,
            initialGeometry: edits.geometry,
            sourceSize: image.size,
            options: options,
            prepareForEditing: true
        ))
#if canImport(PencilKit)
        self._markup = State(initialValue: PhotoMarkupState(
            drawing: edits.markup?.pencilKitDrawing ?? PKDrawing(),
            canvasSize: edits.markup?.canvasSize.cgSize ?? .zero
        ))
#endif
    }

    /// Convenience non-destructive document editor. The source remains unchanged; completion
    /// atomically applies the edit state and rebuilds the persisted thumbnail cache.
    public init?(
        document: SBJImageDocument,
        title: String? = nil,
        options: PhotoEditorOptions = .default,
        allowsUnchangedCompletion: Bool = false,
        onComplete: @escaping (SBJImageDocument?) -> Void
    ) {
        let input = document.editorInput
        self.init(
            resource: input.source,
            edits: input.edits,
            title: title,
            options: options,
            allowsUnchangedCompletion: allowsUnchangedCompletion
        ) { edits in
            guard let edits else {
                onComplete(nil)
                return
            }
            onComplete(document.applying(edits, options: options))
        }
    }

    public var body: some View {
        SBJSharePresentationHost { sharePresenter in
            NavigationStack {
                GeometryReader { proxy in
                    editorCanvas(size: proxy.size)
                        .onChange(of: proxy.size, initial: true) { _, size in
                            model.updateContainerSize(size)
                        }
                }
                .background(Color.black.ignoresSafeArea())
                .navigationTitle(title ?? "")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar(sharePresenter: sharePresenter) }
                .overlay(alignment: .bottom) {
                    straightenOverlay
                }
            }
        }
    }

    @ViewBuilder
    private func editorCanvas(size: CGSize) -> some View {
        let layout = model.layout(in: size)

        ZStack {
            Color.black

            if model.geometry.crop.option != .none, options.renderCropGhost > 0 {
                transformedImage(layout: layout)
                    .position(layout.imageCenter)
                    .opacity(min(options.renderCropGhost, 1))
            }

            ZStack(alignment: .topLeading) {
                transformedImage(layout: layout)
                    .position(layout.imageCenterInFrame)

#if canImport(PencilKit)
                if options.allowsMarkup {
                    PhotoMarkupCanvas(
                        model: markup,
                        isActive: markupActive
                    )
                        .background {
                            GeometryReader { proxy in
                                Color.clear
                                    .onAppear { markup.updateCanvasSize(proxy.size) }
                                    .onChange(of: proxy.size) { _, newSize in
                                        markup.updateCanvasSize(newSize)
                                    }
                            }
                        }
                }
#endif
            }
            .frame(width: layout.frameRect.width, height: layout.frameRect.height)
            .clipped()
            .overlay {
                if model.geometry.crop.option != .none {
                    Rectangle()
                        .stroke(.white.opacity(0.85), lineWidth: 1)
                        .allowsHitTesting(false)

                    if model.geometry.crop.option == .free, !isMarkupActive {
                        Circle()
                            .fill(.white)
                            .frame(width: 18, height: 18)
                            .shadow(radius: 2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .offset(x: 5, y: 5)
                            .contentShape(Rectangle().inset(by: -14))
                            .highPriorityGesture(
                                DragGesture()
                                    .onChanged { value in
                                        model.freeCropChanged(
                                            translation: value.translation,
                                            frameSize: layout.frameRect.size
                                        )
                                    }
                                    .onEnded { _ in
                                        model.freeCropEnded()
                                    }
                            )
                            .accessibility(freeCropInfo)
                    }
                }
            }
            .position(x: layout.frameRect.midX, y: layout.frameRect.midY)
        }
        .contentShape(Rectangle())
        .photoEditGesture(enabled: model.geometry.crop.option != .none && !isMarkupActive, editGesture())
        .onTapGesture(count: 2) {
            guard model.geometry.crop.option != .none, !isMarkupActive else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                model.resetPlacementAndMagnification()
            }
        }
    }

    @ViewBuilder
    private func transformedImage(layout: PhotoResolvedLayout) -> some View {
        Image(uiImage: image)
            .resizable()
            .frame(width: layout.renderedImageSize.width, height: layout.renderedImageSize.height)
            .scaleEffect(x: layout.mirrorX, y: layout.mirrorY)
            .rotationEffect(.radians(layout.rotationRadians))
    }

    private var isMarkupActive: Bool {
#if canImport(PencilKit)
        markupActive
#else
        false
#endif
    }

    private func editGesture() -> some Gesture {
        SimultaneousGesture(
            DragGesture()
                .onChanged { value in
                    model.dragChanged(value.translation)
                }
                .onEnded { _ in
                    model.dragEnded()
                },
            MagnificationGesture()
                .onChanged { value in
                    model.magnificationChanged(Double(value))
                }
                .onEnded { _ in
                    model.magnificationEnded()
                }
        )
    }

    @ToolbarContentBuilder
    private func toolbar(sharePresenter: SBJSharePresenter) -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button("Cancel", role: .cancel) {
                cancel()
            }

            if options.allowsShare {
                Button {
                    guard !sharePresenter.isPresenting,
                          let renderedImageForSharing else { return }
                    _ = sharePresenter.present(SBJSharePayload(renderedImageForSharing))
                } label: {
                    Image(symbol: SBJSymbology.share)
                        .accessibility(AccessibleItem(label: "Share Edited Photo"))
                }
                .disabled(sharePresenter.isPresenting)
            }

			if model.usesCompactToolbar {
	#if canImport(PencilKit)
				if options.allowsMarkup && markup.extendedToolsSupported {
					markupToggleButton
				}
	#endif
			}
        }

        if model.usesCompactToolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
				SBJHelpLink(
					asset: .imageEdit,
					auto: false,
					configuration: .image
				)
                doneButton
            }

            ToolbarItemGroup(placement: .bottomBar) {
#if canImport(PencilKit)
                if options.allowsMarkup, markupActive, markup.extendedToolsSupported {
                    compactMarkupActions
                } else {
                    geometryToolbarButtons
                }
#else
                geometryToolbarButtons
#endif
            }
        } else {
            ToolbarItemGroup(placement: .topBarTrailing) {
#if canImport(PencilKit)
                if options.allowsMarkup, markupActive {
                    SBJImageButton(
                        SBJImageSymbology.eraseMarkup,
                        accessibilityLabel: "Clear Markup",
                        action: markup.clear
                    )
                    .disabled(!markup.hasDrawing)

                    SBJImageButton(
                        SBJImageSymbology.undoMarkup,
                        accessibilityLabel: "Undo Markup",
                        action: markup.undo
                    )
                    .disabled(!markup.canUndo)

                    SBJImageButton(
                        SBJImageSymbology.redoMarkup,
                        accessibilityLabel: "Redo Markup",
                        action: markup.redo
                    )
                    .disabled(!markup.canRedo)
                } else {
                    geometryToolbarButtons
                }

                if options.allowsMarkup && markup.extendedToolsSupported {
                    markupToggleButton
                }
#else
                geometryToolbarButtons
#endif
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                doneButton
            }
        }
    }

    @ViewBuilder
    private var doneButton: some View {
        Button("Done") {
            complete()
        }
        .fontWeight(.semibold)
        .disabled(!canComplete)
        .opacity(canComplete ? 1 : 0.35)
    }

#if canImport(PencilKit)
    @ViewBuilder
    private var markupToggleButton: some View {
        SBJImageButton(
            markupActive ? SBJImageSymbology.hideMarkup : SBJImageSymbology.markup,
            accessibilityLabel: markupActive ? "Hide Markup Tools" : "Show Markup Tools"
        ) {
            markupActive.toggle()
        }
    }
#endif

#if canImport(PencilKit)
    @ViewBuilder
    private var compactMarkupActions: some View {
        SBJImageButton(
            SBJImageSymbology.eraseMarkup,
            accessibilityLabel: "Clear Markup",
            action: markup.clear
        )
        .disabled(!markup.hasDrawing)

        SBJImageButton(
            SBJImageSymbology.undoMarkup,
            accessibilityLabel: "Undo Markup",
            action: markup.undo
        )
        .disabled(!markup.canUndo)

        SBJImageButton(
            SBJImageSymbology.redoMarkup,
            accessibilityLabel: "Redo Markup",
            action: markup.redo
        )
        .disabled(!markup.canRedo)
    }
#endif

    @ViewBuilder
    private func resetPanZoomButton(labelIsHidden: Bool) -> some View {
        Button {
            model.resetPlacementAndMagnification()
        } label: {
            if labelIsHidden {
                Image(symbol: SBJImageSymbology.resetPanZoom)
                    .accessibilityLabel("Reset Pan and Zoom")
            } else {
                Label("Reset Pan & Zoom", symbol: SBJImageSymbology.resetPanZoom)
            }
        }
        .disabled(!model.hasPlacementOrMagnificationEdits)
        .accessibility(
            label: "Reset Pan and Zoom",
            hint: [placementInfo.summary, magnificationInfo.summary].compactMap { $0 }.joined(separator: " ")
        )
    }

    @ViewBuilder
    private var geometryToolbarButtons: some View {
        SBJSelectionMenu {
            if options.showsCropChoices {
                ForEach(options.cropOptions) { option in
                    Button {
                        model.selectCrop(option)
                    } label: {
                        if model.geometry.crop.option == option {
                            Label(cropTitle(for: option), symbol: SBJSymbology.selected)
                        } else {
                            Text(cropTitle(for: option))
                        }
                    }
                    .labelStyle(.titleAndIcon)
                }

                Divider()
            }

            if options.allowsCropDimensionSwap {
                Toggle(isOn: cropDimensionsSwappedBinding) {
                    Label("Swap Width & Height", symbol: SBJImageSymbology.swapCropDimensions)
                }
                .accessibility(swapDimensionsInfo)
            }

            resetPanZoomButton(labelIsHidden: false)
        } collapsedContent: {
            resetPanZoomButton(labelIsHidden: true)
        } label: {
            Image(symbol: SBJImageSymbology.crop)
                .accessibility(cropOptionInfo)
                .accessibilityValue(cropTitle(for: model.geometry.crop.option))
        }

        if options.availableMirrorAxes.contains(.horizontal) {
            SBJImageButton(
                SBJImageSymbology.mirrorHorizontal,
                propertyInfo: horizontalMirrorInfo
            ) {
                model.toggleMirror(.horizontal)
            }
            .accessibilityValue(model.geometry.mirror.horizontal ? "On" : "Off")
        }

        if options.allowsQuarterTurnRotation {
            SBJImageButton(
                SBJImageSymbology.rotateLeft,
                accessibilityLabel: "Rotate Left 90 Degrees",
                accessibilityHint: quarterTurnInfo.accessibilityHint ?? quarterTurnInfo.summary
            ) {
                model.rotate(clockwise: false)
            }
        }

        if options.availableMirrorAxes.contains(.vertical) {
            SBJImageButton(
                SBJImageSymbology.mirrorVertical,
                propertyInfo: verticalMirrorInfo
            ) {
                model.toggleMirror(.vertical)
            }
            .accessibilityValue(model.geometry.mirror.vertical ? "On" : "Off")
        }

        if options.allowsFreeRotation {
            SBJImageButton(
                SBJImageSymbology.straighten,
                propertyInfo: straightenInfo
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isRotationVisible.toggle()
                }
            }
            .accessibilityValue(isRotationVisible ? "Control Shown" : "Control Hidden")
        }
    }

    @ViewBuilder
    private var straightenOverlay: some View {
        if !isMarkupActive && options.allowsFreeRotation && isRotationVisible {
            HStack {
                Text("Straighten")
                    .font(.caption)

                if options.allowsQuarterTurnRotation {
                    SBJImageButton(
                        SBJImageSymbology.rotateLeft,
                        accessibilityLabel: "Rotate Left 90 Degrees",
                        accessibilityHint: quarterTurnInfo.accessibilityHint ?? quarterTurnInfo.summary
                    ) {
                        model.rotate(clockwise: false)
                    }
                }

                Slider(value: fineRotationBinding, in: -15...15)
                    .accessibility(straightenInfo)
                    .accessibilityValue("\(model.geometry.rotation.fineDegrees.formatted(.number.precision(.fractionLength(1)))) degrees")

                Text("\(model.geometry.rotation.degrees.formatted(.number.precision(.fractionLength(1))))°")
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 54, alignment: .trailing)

                if options.allowsQuarterTurnRotation {
                    SBJImageButton(
                        SBJImageSymbology.rotateRight,
                        accessibilityLabel: "Rotate Right 90 Degrees",
                        accessibilityHint: quarterTurnInfo.accessibilityHint ?? quarterTurnInfo.summary
                    ) {
                        model.rotate(clockwise: true)
                    }
                }

                SBJImageButton(
                    SBJImageSymbology.resetStraighten,
                    accessibilityLabel: "Reset Straighten",
                    accessibilityHint: straightenInfo.summary,
                    action: model.resetRotation
                )
                .disabled(!model.hasStraightenEdit)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
    }

    private var cropOptionInfo: SBJPropertyInfo {
        PhotoCropState.propertyInfo(for: \PhotoCropState.option)!
    }

    private var freeCropInfo: SBJPropertyInfo {
        PhotoCropState.propertyInfo(for: \PhotoCropState.freeAspectRatio)!
    }

    private var swapDimensionsInfo: SBJPropertyInfo {
        PhotoCropState.propertyInfo(for: \PhotoCropState.swapsDimensions)!
    }

    private var horizontalMirrorInfo: SBJPropertyInfo {
        PhotoMirrorState.propertyInfo(for: \PhotoMirrorState.horizontal)!
    }

    private var verticalMirrorInfo: SBJPropertyInfo {
        PhotoMirrorState.propertyInfo(for: \PhotoMirrorState.vertical)!
    }

    private var placementInfo: SBJPropertyInfo {
        PhotoEditGeometry.propertyInfo(for: \PhotoEditGeometry.placement)!
    }

    private var magnificationInfo: SBJPropertyInfo {
        PhotoEditGeometry.propertyInfo(for: \PhotoEditGeometry.magnification)!
    }

    private var quarterTurnInfo: SBJPropertyInfo {
        PhotoRotation.propertyInfo(for: \PhotoRotation.quarterTurns)!
    }

    private var straightenInfo: SBJPropertyInfo {
        PhotoRotation.propertyInfo(for: \PhotoRotation.fineDegrees)!
    }

    private func cropTitle(for option: PhotoCropOption) -> String {
        option.title(swappingDimensions: model.geometry.crop.swapsDimensions)
    }

    private var fineRotationBinding: Binding<Double> {
        Binding(
            get: { model.geometry.rotation.fineDegrees },
            set: { degrees in
                model.setFineRotation(degrees)
            }
        )
    }

    private var cropDimensionsSwappedBinding: Binding<Bool> {
        Binding(
            get: { model.geometry.crop.swapsDimensions },
            set: { isSwapped in
                model.setCropDimensionsSwapped(isSwapped)
            }
        )
    }

    private var canComplete: Bool {
        hasEdits || allowsUnchangedCompletion
    }

    private var hasEdits: Bool {
#if canImport(PencilKit)
        model.hasGeometryEdits || markup.hasDrawing
#else
        model.hasGeometryEdits
#endif
    }

    private var requiresRendering: Bool {
        model.geometry.crop.option != .none || hasEdits
    }

    private func cancel() {
        // The editor owns its presentation dismissal. Deliver the cancellation
        // after SwiftUI has begun dismissing so a parent that also clears its
        // presentation binding does not race the local dismiss action.
        dismiss()
        Task { @MainActor in
            await Task.yield()
            onComplete?(nil)
            onEditComplete?(nil)
        }
    }

    private func complete() {
        let resourceResult: SBJResourceContent?
        let editResult: PhotoEditResult?

        if !requiresRendering {
            resourceResult = resource
            editResult = currentEditResult
        } else {
            resourceResult = PhotoEditRenderer.render(
                resource: resource,
                geometry: model.geometry,
                options: options,
                markup: markupForRendering,
                markupCanvasSize: markupSizeForRendering
            )
            editResult = currentEditResult
        }

        dismiss()
        Task { @MainActor in
            await Task.yield()
            if let onEditComplete {
                onEditComplete(editResult)
            } else {
                onComplete?(resourceResult)
            }
        }
    }

    private var currentEditResult: PhotoEditResult {
        PhotoEditResult(
            displayName: initialDisplayName,
            description: initialDescription,
            geometry: model.geometry,
            color: initialColorAdjustments,
            markup: currentMarkup
        )
    }

    private var currentMarkup: PhotoMarkup? {
#if canImport(PencilKit)
        markup.markup
#else
        nil
#endif
    }

    private var markupForRendering: Any? {
#if canImport(PencilKit)
        markup.drawingForRendering
#else
        nil
#endif
    }

    private var markupSizeForRendering: CGSize {
#if canImport(PencilKit)
        markup.canvasSizeForRendering
#else
        .zero
#endif
    }

    private var renderedImageForSharing: UIImage? {
        PhotoEditRenderer.render(
            resource: resource,
            geometry: model.geometry,
            options: options,
            markup: markupForRendering,
            markupCanvasSize: markupSizeForRendering
        )?.uiImage
    }
}
#endif
