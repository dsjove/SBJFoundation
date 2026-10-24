import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Layout configuration for a structured editor tree.
/// Stored on `SBJEditorPresentationModel` and observed by editor rows.
public struct SBJEditorFormattingOptions: Sendable, Equatable {
    public var trailingAlignedFields: Bool
    public var firstLineMinimumHeight: CGFloat
    public var controlLaneWidth: CGFloat
    public var statusLaneWidth: CGFloat
    public var infoLaneWidth: CGFloat
    public var statusToContentSpacing: CGFloat
    public var laneSpacing: CGFloat
    public var indentationWidth: CGFloat
    public var indentBulletDiameter: CGFloat

    public init(
        trailingAlignedFields: Bool = false,
        firstLineMinimumHeight: CGFloat = 28,
        controlLaneWidth: CGFloat = 22,
        statusLaneWidth: CGFloat = 16,
        infoLaneWidth: CGFloat = 24,
        statusToContentSpacing: CGFloat = 3,
        laneSpacing: CGFloat = 5,
        indentationWidth: CGFloat = 8,
        indentBulletDiameter: CGFloat = 3
    ) {
        self.trailingAlignedFields = trailingAlignedFields
        self.firstLineMinimumHeight = firstLineMinimumHeight
        self.controlLaneWidth = controlLaneWidth
        self.statusLaneWidth = statusLaneWidth
        self.infoLaneWidth = infoLaneWidth
        self.statusToContentSpacing = statusToContentSpacing
        self.laneSpacing = laneSpacing
        self.indentationWidth = max(0, indentationWidth)
        self.indentBulletDiameter = indentBulletDiameter
    }

    /// X-coordinate of a hierarchy cue center relative to the editor row edge.
    /// A level-1 cue is centered in the first fixed-width indentation slot.
    func indentBulletCenter(forLevel level: Int) -> CGFloat {
        statusLaneWidth + statusToContentSpacing
            + (CGFloat(max(1, level)) - 0.5) * indentationWidth
    }
}
#endif
