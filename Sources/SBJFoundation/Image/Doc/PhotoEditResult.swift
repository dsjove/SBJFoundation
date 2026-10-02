import Foundation

/// Current non-destructive edit state. This is deliberately not an edit history.
public struct PhotoEditResult: SBJFoundationType, Sendable {
    public var displayName: String
    public var description: String
    public var geometry: PhotoEditGeometry
    public var color: PhotoColorAdjustments
    public var markup: PhotoMarkup?

    public init(
        displayName: String = "",
        description: String = "",
        geometry: PhotoEditGeometry,
        color: PhotoColorAdjustments = .init(),
        markup: PhotoMarkup? = nil
    ) {
        self.displayName = displayName
        self.description = description
        self.geometry = geometry
        self.color = color
        self.markup = markup
    }
}
