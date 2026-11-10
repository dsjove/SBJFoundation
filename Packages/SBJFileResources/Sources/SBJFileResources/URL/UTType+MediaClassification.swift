import UniformTypeIdentifiers

/// Generic content classification, independent of a particular URL or application.
public extension UTType {
    var isMovieMedia: Bool { conforms(to: .movie) || conforms(to: .video) }
    var isImageMedia: Bool { conforms(to: .image) }
    var isAudioMedia: Bool { conforms(to: .audio) }
    var isWebLocationDocument: Bool {
        conforms(to: .url) || identifier == "com.apple.web-internet-location"
    }
}
