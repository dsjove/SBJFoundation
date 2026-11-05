import Foundation
import UniformTypeIdentifiers

/// Cross-platform, UTI-based classification for file and remote URLs.
/// Valid for registered movie types regardless of filename extension spelling.
public extension URL {
    var mediaContentType: UTType? {
        if isFileURL,
           let type = try? resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type
        }
        return UTType(filenameExtension: pathExtension)
    }

    var isMovieMedia: Bool {
        guard let type = mediaContentType else { return false }
        return type.conforms(to: .movie) || type.conforms(to: .video)
    }

    var isMovieMediaFile: Bool {
        isFileURL && isMovieMedia
    }

    var isImageMedia: Bool { mediaContentType?.conforms(to: .image) == true }
    var isAudioMedia: Bool { mediaContentType?.conforms(to: .audio) == true }
}
