import Foundation
import Testing
@testable import SBJImaging

@MainActor
struct PosterFrameCacheTests {

    @Test func negativeTimeIsCachedAsMissingWithoutExtraction() async {
        var fetches = 0
        let cache = PosterFrameCache { _ in fetches += 1; return nil }
        let url = URL(fileURLWithPath: "/tmp/no-poster.mov")
        let negative = PosterFrameCache.Key(url, -1)
        let first = await cache.thumbnail(for: negative)
        let second = await cache.thumbnail(for: negative)
        #expect(first.image == nil)
        #expect(second.image == nil)
        #expect(fetches == 0)
        #expect(cache.cached(negative) != nil)
    }

    @Test func nilIsDistinctAndCached() async {
        var count = 0
        let cache = PosterFrameCache { _ in count += 1; return nil }
        let url = URL(fileURLWithPath: "/tmp/example.mp4")
        let absent = PosterFrameCache.Key(url, nil)
        _ = await cache.thumbnail(for: absent)
        _ = await cache.thumbnail(for: absent)
        #expect(count == 1)
        #expect(cache.cached(PosterFrameCache.Key(url, 0)) == nil)
    }
}
