#if !os(watchOS) && !os(tvOS)
import Foundation
import UniformTypeIdentifiers
import SBJFileResources

/// Application-level staging for appending clips. The shared joiner only joins a folder.
@MainActor
public enum MovieAppendWorkflow {
    public enum Error: LocalizedError {
        case noClips, missingOriginal, existingFolder(String), existingOutput(String)
        case invalidMovie(String), restoreFailed(String, String)

        public var errorDescription: String? {
            switch self {
            case .noClips: "Select at least one additional movie."
            case .missingOriginal: "The original movie is missing."
            case .existingFolder(let name): "The working folder ‘\(name)’ already exists."
            case .existingOutput(let name): "The output ‘\(name)’ already exists."
            case .invalidMovie(let name): "‘\(name)’ is not a movie file."
            case .restoreFailed(let folder, let detail):
                "Could not restore the original from ‘\(folder)’: \(detail)"
            }
        }
    }

    public static func append(to movie: URL, additionalFiles: [URL],
                       update: @escaping @MainActor (String) -> Void) async throws -> URL {
        guard !additionalFiles.isEmpty else { throw Error.noClips }
        let fm = FileManager.default
        let parent = movie.deletingLastPathComponent()
        let scope = parent.startAccessingSecurityScopedResource()
        defer { if scope { parent.stopAccessingSecurityScopedResource() } }

        let name = movie.deletingPathExtension().lastPathComponent
        let folder = parent.appendingPathComponent(name, isDirectory: true)
        let destination = parent.appendingPathComponent(name).appendingPathExtension("mov")
        guard fm.fileExists(atPath: movie.path) else { throw Error.missingOriginal }
        guard !fm.fileExists(atPath: folder.path) else { throw Error.existingFolder(folder.lastPathComponent) }
        guard destination.standardizedFileURL == movie.standardizedFileURL ||
              !fm.fileExists(atPath: destination.path) else {
            throw Error.existingOutput(destination.lastPathComponent)
        }
        // Validate the selected URL's resource content type, not its filename extension.
        for file in additionalFiles {
            let accessed = file.startAccessingSecurityScopedResource()
            defer { if accessed { file.stopAccessingSecurityScopedResource() } }
            let values = try file.resourceValues(forKeys: [.isRegularFileKey, .contentTypeKey])
            guard values.isRegularFile == true, values.contentType?.conforms(to: .movie) == true else {
                throw Error.invalidMovie(file.lastPathComponent)
            }
        }

        try fm.createDirectory(at: folder, withIntermediateDirectories: false)
        let stagedOriginal = folder.appendingPathComponent("0000_" + movie.lastPathComponent)
        var movedOriginal = false
        var published = false
        do {
            update("Moving original movie…")
            try fm.moveItem(at: movie, to: stagedOriginal)
            movedOriginal = true
            for (index, file) in additionalFiles.enumerated() {
                update("Copying \(index + 1) of \(additionalFiles.count)…")
                let accessed = file.startAccessingSecurityScopedResource()
                defer { if accessed { file.stopAccessingSecurityScopedResource() } }
                let numbered = String(format: "%04d_%@", index + 1, file.lastPathComponent)
                try fm.copyItem(at: file, to: folder.appendingPathComponent(numbered))
            }
            // No changes to the shared movie-join algorithm or its public API.
            let joined = try await MovieFolderJoiner.join(directory: folder, update: update)
            update("Publishing joined movie…")
            guard !fm.fileExists(atPath: destination.path) else {
                throw Error.existingOutput(destination.lastPathComponent)
            }
            try fm.moveItem(at: joined, to: destination)
            published = true
            update("Cleaning up…")
            do { try fm.removeItem(at: folder) }
            catch { update("Created movie; working folder cleanup failed: \(error.localizedDescription)") }
            return destination
        } catch {
            if movedOriginal && !published && !fm.fileExists(atPath: movie.path) {
                do { try fm.moveItem(at: stagedOriginal, to: movie) }
                catch { throw Error.restoreFailed(folder.path, error.localizedDescription) }
            }
            if !movedOriginal { try? fm.removeItem(at: folder) }
            throw error
        }
    }
}

#endif
