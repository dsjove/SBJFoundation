import Observation
import SBJDataDefinition
import SwiftUI
import UIKit

@MainActor
@Observable
final class PhotoViewerTransform {
    let sourceSize: CGSize
    let maximumScale: CGFloat

    var containerSize: CGSize = .zero {
        didSet {
            guard containerSize != oldValue else { return }
            clampOffset()
        }
    }

    private(set) var scale: CGFloat = 1
    private(set) var offset: CGSize = .zero

    private var dragStartOffset: CGSize?
    private var magnificationStartScale: CGFloat?

    init(sourceSize: CGSize, maximumScale: CGFloat) {
        self.sourceSize = sourceSize
        self.maximumScale = max(1, maximumScale)
    }

    var fittedSize: CGSize {
        guard sourceSize.width > 0,
              sourceSize.height > 0,
              containerSize.width > 0,
              containerSize.height > 0
        else { return .zero }

        let fit = min(
            containerSize.width / sourceSize.width,
            containerSize.height / sourceSize.height
        )
        return CGSize(
            width: sourceSize.width * fit,
            height: sourceSize.height * fit
        )
    }

    var isAtRest: Bool {
        abs(scale - 1) < 0.0001
        && abs(offset.width) < 0.0001
        && abs(offset.height) < 0.0001
    }

    func dragChanged(_ translation: CGSize) {
        let origin = dragStartOffset ?? offset
        if dragStartOffset == nil {
            dragStartOffset = origin
        }
        offset = clampedOffset(CGSize(
            width: origin.width + translation.width,
            height: origin.height + translation.height
        ))
    }

    func dragEnded() {
        dragStartOffset = nil
    }

    func magnificationChanged(_ magnification: CGFloat) {
        let origin = magnificationStartScale ?? scale
        if magnificationStartScale == nil {
            magnificationStartScale = origin
        }
        scale = min(max(origin * magnification, 1), maximumScale)
        clampOffset()
    }

    func magnificationEnded() {
        magnificationStartScale = nil
    }

    func resetPosition() {
        scale = 1
        offset = .zero
        dragStartOffset = nil
        magnificationStartScale = nil
    }

    private func clampOffset() {
        offset = clampedOffset(offset)
    }

    private func clampedOffset(_ proposed: CGSize) -> CGSize {
        let size = fittedSize
        guard size != .zero else { return .zero }

        let renderedWidth = size.width * scale
        let renderedHeight = size.height * scale
        let maxX = max(0, (renderedWidth - containerSize.width) / 2)
        let maxY = max(0, (renderedHeight - containerSize.height) / 2)

        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }
}
