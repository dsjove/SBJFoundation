import Foundation

/// An encoded still image returned by the camera UI.
///
/// `blob` contains encoded image bytes, while `utiType` identifies their format
/// (currently JPEG for both built-in capture implementations). Consumers can
/// persist these bytes directly without decoding and re-encoding an image.
public struct CapturedAttachment: Sendable {
    public let blob: Data
    public let utiType: String

    public init(blob: Data, utiType: String) {
        self.blob = blob
        self.utiType = utiType
    }
}
