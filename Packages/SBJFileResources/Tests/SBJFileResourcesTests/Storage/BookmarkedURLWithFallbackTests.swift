import Foundation
import Testing
@testable import SBJFileResources

@Suite("Bookmarked URL path fallback")
struct BookmarkedURLWithFallbackTests {
    @Test("Returns the saved path without bookmark data")
    func restoresPathWithoutBookmark() throws {
        let suite = "SBJBookmarkFallbackTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let location = BookmarkedURLWithFallback(
            bookmarkKey: "bookmark", pathKey: "path", defaults: defaults
        )
        defaults.set("/Volumes/Offline/Films", forKey: "path")
        #expect(location.resolve()?.path == "/Volumes/Offline/Films")
        #expect(location.refresh()?.path == "/Volumes/Offline/Films")
    }

    @Test("Invalid bookmark falls back to saved path")
    func invalidBookmark() throws {
        let suite = "SBJBookmarkFallbackTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let location = BookmarkedURLWithFallback(
            bookmarkKey: "bookmark", pathKey: "path", defaults: defaults
        )
        defaults.set("/Volumes/Offline/Films", forKey: "path")
        defaults.set(Data([0, 1, 2, 3]), forKey: "bookmark")
        #expect(location.resolve()?.path == "/Volumes/Offline/Films")
    }
}
