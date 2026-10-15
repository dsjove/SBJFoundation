#if !os(watchOS) && !os(tvOS) && canImport(UIKit)
import Observation
import SwiftUI
import UIKit
import SBJShared

/// Mutable interaction state for a photo-editing session.
///
/// `PhotoEditGeometry` remains the portable edit recipe. This model owns the
/// transient state needed to manipulate that recipe in the editor: container
/// sizing, gesture origins and free-crop drag state.
@MainActor
@Observable
final class PhotoEditorModel {
    private(set) var geometry: PhotoEditGeometry
    let initialGeometry: PhotoEditGeometry

    let sourceSize: CGSize
    let options: PhotoEditorOptions

    private(set) var containerSize: CGSize = .zero

    private var dragStartGeometry: PhotoEditGeometry?
    private var magnificationStartGeometry: PhotoEditGeometry?
    private var freeCropStartAspect: Double?
    private var freeCropStartFrameSize: CGSize?

    init(
        geometry: PhotoEditGeometry,
        initialGeometry: PhotoEditGeometry? = nil,
        sourceSize: CGSize,
        options: PhotoEditorOptions,
        prepareForEditing: Bool = false
    ) {
        var editable = geometry
        if prepareForEditing {
            editable.prepareForEditing(
                supportedCropOptions: options.cropOptions,
                sourceSize: sourceSize
            )
        }

        self.geometry = editable
        self.initialGeometry = initialGeometry ?? geometry
        self.sourceSize = sourceSize
        self.options = options
    }

    var usesCompactToolbar: Bool {
        containerSize.width < 600
    }

    var hasGeometryEdits: Bool {
        geometry.editComparisonValue != initialGeometry.editComparisonValue
    }

    var hasPlacementOrMagnificationEdits: Bool {
        geometry.hasPlacementOrMagnificationEdits
    }

    var hasStraightenEdit: Bool {
        geometry.hasStraightenEdit
    }

    func layout(in containerSize: CGSize) -> PhotoResolvedLayout {
        PhotoGeometryResolver.resolve(
            sourceSize: sourceSize,
            containerSize: containerSize,
            geometry: geometry,
            options: options
        )
    }

    func updateContainerSize(_ size: CGSize) {
        guard size != containerSize else { return }
        containerSize = size
        constrainCurrentGeometry()
    }

    func selectCrop(_ option: PhotoCropOption) {
        geometry.selectCrop(option)
        resetGestureOrigins()
        constrainCurrentGeometry()
    }

    func setCropDimensionsSwapped(_ isSwapped: Bool) {
        geometry.setCropDimensionsSwapped(isSwapped)
        resetGestureOrigins()
        constrainCurrentGeometry()
    }

    func freeCropChanged(translation: CGSize, frameSize: CGSize) {
        let startAspect = freeCropStartAspect ?? geometry.crop.freeAspectRatio
        let startSize = freeCropStartFrameSize ?? frameSize

        if freeCropStartAspect == nil {
            freeCropStartAspect = startAspect
            freeCropStartFrameSize = startSize
        }

        let newWidth = max(40, startSize.width + translation.width)
        let newHeight = max(40, startSize.height + translation.height)
        geometry.resizeFreeCrop(to: Double(newWidth / newHeight))
        constrainCurrentGeometry()
    }

    func freeCropEnded() {
        freeCropStartAspect = nil
        freeCropStartFrameSize = nil
    }

    func resetPlacementAndMagnification() {
        geometry.resetPlacementAndMagnification()
        dragStartGeometry = nil
        magnificationStartGeometry = nil
        constrainCurrentGeometry()
    }

    func toggleMirror(_ axis: PhotoMirrorAxis) {
        geometry.toggleMirror(axis)
    }

    func rotate(clockwise: Bool) {
        geometry.rotate(clockwise: clockwise)
        resetGestureOrigins()
        constrainCurrentGeometry()
    }

    func setFineRotation(_ degrees: Double) {
        geometry.setFineRotation(degrees)
        constrainCurrentGeometry()
    }

    func resetRotation() {
        geometry.resetRotation()
        resetGestureOrigins()
        constrainCurrentGeometry()
    }

    func resetStraighten() {
        geometry.resetStraighten()
        constrainCurrentGeometry()
    }

    func dragChanged(_ translation: CGSize) {
        let start = dragStartGeometry ?? geometry
        if dragStartGeometry == nil {
            dragStartGeometry = start
        }
        geometry = start.panned(
            by: translation,
            sourceSize: sourceSize,
            containerSize: containerSize,
            options: options
        )
    }

    func dragEnded() {
        dragStartGeometry = nil
    }

    func magnificationChanged(_ scale: Double) {
        let start = magnificationStartGeometry ?? geometry
        if magnificationStartGeometry == nil {
            magnificationStartGeometry = start
        }
        geometry = start.magnified(
            by: scale,
            sourceSize: sourceSize,
            containerSize: containerSize,
            options: options
        )
    }

    func magnificationEnded() {
        magnificationStartGeometry = nil
    }

    private func resetGestureOrigins() {
        dragStartGeometry = nil
        magnificationStartGeometry = nil
        freeCropStartAspect = nil
        freeCropStartFrameSize = nil
    }

    private func constrainCurrentGeometry() {
        guard containerSize.width > 0, containerSize.height > 0 else { return }
        geometry = geometry.constrained(
            sourceSize: sourceSize,
            containerSize: containerSize,
            options: options
        )
    }
}
#endif
