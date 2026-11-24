#if !os(watchOS) && !os(tvOS)
import Testing
@testable import SBJImaging

@MainActor
struct MovieJoinCoordinatorTests {
    @Test func selectionPreparationDoesNotStartJoining() {
        let coordinator = MovieJoinCoordinator()
        coordinator.prepareSelection()
        #expect(!coordinator.isJoiningMovies)
        #expect(coordinator.joinMovieProgress == nil)
        #expect(coordinator.joinMovieError == nil)
    }

    @Test func errorsAreAvailableToThePresentation() {
        let coordinator = MovieJoinCoordinator()
        coordinator.joinMovieError = "Cannot open directory"
        #expect(coordinator.joinMovieError == "Cannot open directory")
        coordinator.joinMovieError = nil
        #expect(coordinator.joinMovieError == nil)
    }
}

#endif
