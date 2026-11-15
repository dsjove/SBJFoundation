import Foundation
import Observation

/// Manages the join lifecycle and its progress/error presentation.
/// The underlying filesystem operation remains in MovieFolderJoiner.
@MainActor @Observable
public final class MovieJoinCoordinator {
    public private(set) var isJoiningMovies = false
    public private(set) var joinMovieProgress: String?
    
    public var joinMovieError: String?

    public func prepareSelection() { joinMovieProgress = nil }

    public init() {}

    public func start(source: URL) {
        guard !isJoiningMovies else { return }
        isJoiningMovies = true
        joinMovieProgress = "Preparing \(source.lastPathComponent)…"
        Task { @MainActor in
            defer { isJoiningMovies = false }
            await Task.yield()
            do {
                let output = try await MovieFolderJoiner.join(directory: source) {
                    self.joinMovieProgress = $0
                }
                joinMovieProgress = "Created \(output.lastPathComponent) inside \(source.lastPathComponent)."
            } catch {
                joinMovieProgress = nil
                joinMovieError = error.localizedDescription
            }
        }
    }
}
