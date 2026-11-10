import Foundation
import UniformTypeIdentifiers

/// Content-type resolution for URLs. Filesystem metadata wins when available;
/// extension inference is a fallback, and does not assert that a file exists.
public extension URL {
    var inferredContentType: UTType? { UTType(filenameExtension: pathExtension) }

    var fileContentType: UTType? {
        guard isFileURL else { return nil }
        return (try? resourceValues(forKeys: [.contentTypeKey]))?.contentType
    }

	//Must be local file
    var mediaContentType: UTType? { isFileURL ? fileContentType ?? inferredContentType : nil }
    var isMovieMedia: Bool { mediaContentType?.isMovieMedia == true }
    var isImageMedia: Bool { mediaContentType?.isImageMedia == true }
    var isAudioMedia: Bool { mediaContentType?.isAudioMedia == true }

    var isWebLocation: Bool {
        // A remote URL is not a local .webloc document.
        isFileURL && (pathExtension.lowercased() == "webloc" ||
            mediaContentType?.isWebLocationDocument == true)
    }

    /// Read the HTTP(S) destination of a local macOS .webloc document.
    /// The caller must hold any required security-scoped access during the read.
    func readWebLink() throws -> URL {
        guard isFileURL, pathExtension.lowercased() == "webloc" else {
            throw WebLinkError.notWebLink
        }
        let data = try Data(contentsOf: self)
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dictionary = plist as? [String: Any],
              let address = dictionary["URL"] as? String,
              let destination = URL(string: address),
              ["http", "https"].contains(destination.scheme?.lowercased() ?? ""),
              destination.host != nil else {
            throw WebLinkError.invalidDestination
        }
        return destination
    }
}

public enum WebLinkError: LocalizedError {
    case notWebLink
    case invalidDestination

    public var errorDescription: String? {
        switch self {
        case .notWebLink: "URL is not a local .webloc document."
        case .invalidDestination: "Web location does not contain a valid HTTP(S) destination."
        }
    }
}
