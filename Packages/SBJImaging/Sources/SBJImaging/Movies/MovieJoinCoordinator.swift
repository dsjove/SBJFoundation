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

    /// Appends selected movies to a library movie, using the same progress UI
    /// and error presentation as the folder-based movie joiner.
    public func append(movieName: String,
                       operation: @escaping @MainActor (@escaping @MainActor (String) -> Void) async throws -> URL,
                       onComplete: @escaping @MainActor () -> Void) {
        guard !isJoiningMovies else { return }
        isJoiningMovies = true
        joinMovieError = nil
        joinMovieProgress = "Preparing \(movieName)…"
        Task { @MainActor in
            defer { isJoiningMovies = false }
            await Task.yield()
            do {
                let output = try await operation { self.joinMovieProgress = $0 }
                joinMovieProgress = "Created \(output.lastPathComponent)."
                onComplete()
            } catch {
                joinMovieProgress = nil
                joinMovieError = error.localizedDescription
            }
        }
    }

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
