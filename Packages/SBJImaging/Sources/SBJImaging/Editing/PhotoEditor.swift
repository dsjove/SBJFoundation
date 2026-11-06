#if !os(watchOS) && !os(tvOS) && (canImport(UIKit) || canImport(AppKit))
import SBJLocalization
import Observation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import CoreImage
#if canImport(UIKit) && canImport(PencilKit)
import PencilKit
#endif
import SBJFileResources
import SBJDataDefinition
import SBJDocuments
import SBJUIVocabulary
import SBJHelp
import SBJSharing

public extension SBJBundledContentReference {
    static var imageEditHelp: SBJBundledContentReference {
        .help("Image Edit", bundle: .module)
    }
}

/// Full-screen image editor backed by normalized edit geometry.
///
/// Persistent edits are represented by PhotoEditGeometry. The SwiftUI canvas
/// and PhotoEditRenderer both resolve that same geometry, so crop/placement,
/// rotation and mirror have one source of truth for presentation and export.
@MainActor
public struct PhotoEditor: View {
    private let resource: SBJResourceContent
    private let image: SBJImage
    private let previewImage: SBJImage
    private let initialColorAdjustments: PhotoColorAdjustments
    private let preservedMarkup: PhotoMarkup?
    private let title: String?
    private let options: PhotoEditorOptions
    private let onComplete: ((SBJResourceContent?) -> Void)?
    private let onEditComplete: ((PhotoEditResult?) -> Void)?
    private let initialDisplayName: String
    private let initialDescription: String
    @State private var colorAdjustments: PhotoColorAdjustments
    @State private var enhancementsEnabled = true
    @State private var showEnhancements = false
    private let allowsUnchangedCompletion: Bool
    /// Set false when embedded directly in a parent view rather than presented as a sheet.
    private let dismissOnCompletion: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var model: PhotoEditorModel
    /// UI preference only; persisted independently from image edit state.
    @AppStorage("SBJFoundation.PhotoEditor.isRotationVisible")
    private var isRotationVisible = false
#if canImport(UIKit) && canImport(PencilKit)
    @State private var markup: PhotoMarkupState
    @AppStorage("SBJFoundation.PhotoEditor.markupActive")
    private var markupActive = false
#endif

    public init?(
        resource: SBJResourceContent,
        title: String? = nil,
        options: PhotoEditorOptions = .default,
        allowsUnchangedCompletion: Bool = false,
        dismissOnCompletion: Bool = true,
        onComplete: @escaping (SBJResourceContent?) -> Void
    ) {
        guard let image = resource.sbjImage else { return nil }
        self.resource = resource
        self.image = image
        self.previewImage = Self.previewSized(image)
        self.title = title
        self.options = options
        self.onComplete = onComplete
        self.onEditComplete = nil
        self.initialDisplayName = ""
        self.initialDescription = ""
        self.initialColorAdjustments = .init()
        self.preservedMarkup = nil
        self._colorAdjustments = State(initialValue: .init())
        self.allowsUnchangedCompletion = allowsUnchangedCompletion
        self.dismissOnCompletion = dismissOnCompletion

        let initial = PhotoEditGeometry(crop: .init(option: options.effectiveInitialCrop, sourceSize: image.size))
        self._model = State(initialValue: PhotoEditorModel(
            geometry: initial,
            sourceSize: image.size,
            options: options
        ))
#if canImport(UIKit) && canImport(PencilKit)
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
        dismissOnCompletion: Bool = true,
        onComplete: @escaping (PhotoEditResult?) -> Void
    ) {
        guard let image = resource.sbjImage else { return nil }
        self.resource = resource
        self.image = image
        self.previewImage = Self.previewSized(image)
        self.title = title
        self.options = options
        self.onComplete = nil
        self.onEditComplete = onComplete
        self.initialDisplayName = edits.displayName
        self.initialDescription = edits.description
        self.initialColorAdjustments = edits.color
        self.preservedMarkup = edits.markup
        self._colorAdjustments = State(initialValue: edits.color)
        self.allowsUnchangedCompletion = allowsUnchangedCompletion
        self.dismissOnCompletion = dismissOnCompletion
        self._model = State(initialValue: PhotoEditorModel(
            geometry: edits.geometry,
            initialGeometry: edits.geometry,
            sourceSize: image.size,
            options: options,
            prepareForEditing: true
        ))
#if canImport(UIKit) && canImport(PencilKit)
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
        dismissOnCompletion: Bool = true,
        onComplete: @escaping (SBJImageDocument?) -> Void
    ) {
        let input = document.editorInput
        self.init(
            resource: input.source,
            edits: input.edits,
            title: title,
            options: options,
            allowsUnchangedCompletion: allowsUnchangedCompletion,
            dismissOnCompletion: dismissOnCompletion
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
                #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar { toolbar(sharePresenter: sharePresenter) }
                .overlay(alignment: .bottom) {
                    straightenOverlay
                    #if os(macOS)
                    if preservedMarkup != nil {
                        Text("This photo contains markup that cannot be edited on macOS.")
                            .padding().background(.regularMaterial)
                    }
                    #endif
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

#if canImport(UIKit) && canImport(PencilKit)
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
        enhancedPreviewImage.sbjSwiftUIImage
            .resizable()
            .frame(width: layout.renderedImageSize.width, height: layout.renderedImageSize.height)
            .scaleEffect(x: layout.mirrorX, y: layout.mirrorY)
            .rotationEffect(.radians(layout.rotationRadians))
    }

    private static let previewContext = CIContext()

    /// GPU filters operate on a display-sized preview during slider dragging.
    /// The renderer always processes the full-resolution source on completion.
    private static func previewSized(_ image: SBJImage) -> SBJImage {
        let largest = max(image.size.width, image.size.height)
        guard largest > 1600 else { return image }
        let scale = 1600 / largest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        #if canImport(UIKit)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        #else
        guard let cg = image.sbjCGImage else { return image }
        let source = CIImage(cgImage: cg)
        let reduced = source.transformed(by: .init(scaleX: scale, y: scale))
        guard let result = previewContext.createCGImage(reduced, from: reduced.extent) else { return image }
        return NSImage(cgImage: result, size: size)
        #endif
    }

    private var enhancedPreviewImage: SBJImage {
        guard enhancementsEnabled else { return image }
        return colorAdjustments.applying(to: previewImage, context: Self.previewContext) ?? previewImage
    }

    private var isMarkupActive: Bool {
#if canImport(UIKit) && canImport(PencilKit)
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
        ToolbarItemGroup(placement: editorLeadingPlacement) {
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
	#if canImport(UIKit) && canImport(PencilKit)
				if options.allowsMarkup && markup.extendedToolsSupported {
					markupToggleButton
				}
	#endif
			}
        }

        if model.usesCompactToolbar {
            ToolbarItemGroup(placement: editorTrailingPlacement) {
				SBJHelpLink(
					asset: .imageEditHelp,
					auto: false,
					configuration: .imageHelp
				)
                enhancementButton
                doneButton
            }

            ToolbarItemGroup(placement: editorBottomPlacement) {
#if canImport(UIKit) && canImport(PencilKit)
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
            ToolbarItemGroup(placement: editorTrailingPlacement) {
#if canImport(UIKit) && canImport(PencilKit)
                if options.allowsMarkup, markupActive {
                    SBJSymbolButton(
                        SBJImageSymbology.eraseMarkup,
                        accessibilityLabel: "Clear Markup",
                        action: markup.clear
                    )
                    .disabled(!markup.hasDrawing)

                    SBJSymbolButton(
                        SBJImageSymbology.undoMarkup,
                        accessibilityLabel: "Undo Markup",
                        action: markup.undo
                    )
                    .disabled(!markup.canUndo)

                    SBJSymbolButton(
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
            ToolbarItemGroup(placement: editorTrailingPlacement) {
                enhancementButton
                doneButton
            }
        }
    }

    private var editorLeadingPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .automatic
        #else
        .topBarLeading
        #endif
    }
    private var editorTrailingPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .automatic
        #else
        .topBarTrailing
        #endif
    }
    private var editorBottomPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .automatic
        #else
        .bottomBar
        #endif
    }

    private var enhancementButton: some View {
        Button("Enhancements", systemImage: "slider.horizontal.3") {
            showEnhancements.toggle()
        }
        .labelStyle(.iconOnly)
        .popover(isPresented: $showEnhancements) {
            ImageEnhancementControls(
                adjustments: $colorAdjustments,
                isEnabled: $enhancementsEnabled
            )
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

#if canImport(UIKit) && canImport(PencilKit)
    @ViewBuilder
    private var markupToggleButton: some View {
        SBJSymbolButton(
            markupActive ? SBJImageSymbology.hideMarkup : SBJImageSymbology.markup,
            accessibilityLabel: markupActive ? "Hide Markup Tools" : "Show Markup Tools"
        ) {
            markupActive.toggle()
        }
    }
#endif

#if canImport(UIKit) && canImport(PencilKit)
    @ViewBuilder
    private var compactMarkupActions: some View {
        SBJSymbolButton(
            SBJImageSymbology.eraseMarkup,
            accessibilityLabel: "Clear Markup",
            action: markup.clear
        )
        .disabled(!markup.hasDrawing)

        SBJSymbolButton(
            SBJImageSymbology.undoMarkup,
            accessibilityLabel: "Undo Markup",
            action: markup.undo
        )
        .disabled(!markup.canUndo)

        SBJSymbolButton(
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
            SBJSymbolButton(
                SBJImageSymbology.mirrorHorizontal,
                accessibilityLabel: horizontalMirrorInfo.accessibilityLabel ?? horizontalMirrorInfo.title ?? horizontalMirrorInfo.summary ?? "Mirror Horizontally",
                accessibilityHint: horizontalMirrorInfo.accessibilityHint ?? horizontalMirrorInfo.summary
            ) {
                model.toggleMirror(.horizontal)
            }
            .accessibilityValue(model.geometry.mirror.horizontal ? "On" : "Off")
        }

        if options.allowsQuarterTurnRotation {
            SBJSymbolButton(
                SBJImageSymbology.rotateLeft,
                accessibilityLabel: "Rotate Left 90 Degrees",
                accessibilityHint: quarterTurnInfo.accessibilityHint ?? quarterTurnInfo.summary
            ) {
                model.rotate(clockwise: false)
            }
        }

        if options.availableMirrorAxes.contains(.vertical) {
            SBJSymbolButton(
                SBJImageSymbology.mirrorVertical,
                accessibilityLabel: verticalMirrorInfo.accessibilityLabel ?? verticalMirrorInfo.title ?? verticalMirrorInfo.summary ?? "Mirror Vertically",
                accessibilityHint: verticalMirrorInfo.accessibilityHint ?? verticalMirrorInfo.summary
            ) {
                model.toggleMirror(.vertical)
            }
            .accessibilityValue(model.geometry.mirror.vertical ? "On" : "Off")
        }

        if options.allowsFreeRotation {
            SBJSymbolButton(
                SBJImageSymbology.straighten,
                accessibilityLabel: straightenInfo.accessibilityLabel ?? straightenInfo.title ?? straightenInfo.summary ?? "Straighten",
                accessibilityHint: straightenInfo.accessibilityHint ?? straightenInfo.summary
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
                    SBJSymbolButton(
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
                    SBJSymbolButton(
                        SBJImageSymbology.rotateRight,
                        accessibilityLabel: "Rotate Right 90 Degrees",
                        accessibilityHint: quarterTurnInfo.accessibilityHint ?? quarterTurnInfo.summary
                    ) {
                        model.rotate(clockwise: true)
                    }
                }

                SBJSymbolButton(
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
        PhotoCropState.optionInfo
    }

    private var freeCropInfo: SBJPropertyInfo {
        PhotoCropState.freeAspectRatioInfo
    }

    private var swapDimensionsInfo: SBJPropertyInfo {
        PhotoCropState.swapsDimensionsInfo
    }

    private var horizontalMirrorInfo: SBJPropertyInfo {
        PhotoMirrorState.horizontalInfo
    }

    private var verticalMirrorInfo: SBJPropertyInfo {
        PhotoMirrorState.verticalInfo
    }

    private var placementInfo: SBJPropertyInfo {
        PhotoEditGeometry.placementInfo
    }

    private var magnificationInfo: SBJPropertyInfo {
        PhotoEditGeometry.magnificationInfo
    }

    private var quarterTurnInfo: SBJPropertyInfo {
        PhotoRotation.quarterTurnsInfo
    }

    private var straightenInfo: SBJPropertyInfo {
        PhotoRotation.fineDegreesInfo
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
        #if os(macOS)
        // Never discard a markup layer that this platform cannot render.
        if preservedMarkup != nil { return false }
        #endif
        return hasEdits || allowsUnchangedCompletion
    }

    private var hasEdits: Bool {
        if colorAdjustments != initialColorAdjustments { return true }
#if canImport(UIKit) && canImport(PencilKit)
        return model.hasGeometryEdits || markup.hasDrawing
#else
        return model.hasGeometryEdits
#endif
    }

    private var requiresRendering: Bool {
        model.geometry.crop.option != .none || hasEdits
    }

    /// Modal presentations own their dismissal. Embedded presentations are
    /// removed by their parent after the completion callback; calling dismiss()
    /// there would dismiss the *parent* viewer instead.
    private func deliverCompletion(_ callback: @escaping @MainActor () -> Void) {
        if dismissOnCompletion {
            dismiss()
            Task { @MainActor in
                await Task.yield()
                callback()
            }
        } else {
            callback()
        }
    }

    private func cancel() {
        deliverCompletion {
            onComplete?(nil)
            onEditComplete?(nil)
        }
    }

    private func complete() {
        guard canComplete else { return }
        let resourceResult: SBJResourceContent?
        let editResult: PhotoEditResult?

        if !requiresRendering {
            resourceResult = resource
            editResult = currentEditResult
        } else {
            resourceResult = PhotoEditRenderer.render(
                resource: resource,
                geometry: model.geometry,
                color: colorAdjustments,
                options: options,
                markup: markupForRendering,
                markupCanvasSize: markupSizeForRendering
            )
            editResult = currentEditResult
        }

        deliverCompletion {
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
            color: colorAdjustments,
            markup: currentMarkup
        )
    }

    private var currentMarkup: PhotoMarkup? {
#if canImport(UIKit) && canImport(PencilKit)
        markup.markup
#else
        preservedMarkup
#endif
    }

    private var markupForRendering: Any? {
#if canImport(UIKit) && canImport(PencilKit)
        markup.drawingForRendering
#else
        nil
#endif
    }

    private var markupSizeForRendering: CGSize {
#if canImport(UIKit) && canImport(PencilKit)
        markup.canvasSizeForRendering
#else
        .zero
#endif
    }

    private var renderedImageForSharing: SBJImage? {
        PhotoEditRenderer.render(
            resource: resource,
            geometry: model.geometry,
            color: colorAdjustments,
            options: options,
            markup: markupForRendering,
            markupCanvasSize: markupSizeForRendering
        )?.sbjImage
    }
}
#endif
