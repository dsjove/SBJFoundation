import Foundation
import Testing
@testable import SBJImaging

@MainActor
struct PosterFrameCacheIntegrationTests {
    @Test func nilTimeIsCachedAndDifferentFromZero() async {
        var fetches = 0
        let cache = PosterFrameCache { _ in fetches += 1; return nil }
        let url = URL(fileURLWithPath: "/tmp/NoPoster.mp4")
        let empty = PosterFrameCache.Key(url, nil)
        let zero = PosterFrameCache.Key(url, 0)
        #expect(cache.cached(empty) == nil)
        _ = await cache.thumbnail(for: empty)
        _ = await cache.thumbnail(for: empty)
        #expect(fetches == 1)
        #expect(cache.cached(empty) != nil)
        #expect(cache.cached(empty)?.image == nil)
        #expect(cache.cached(zero) == nil)
    }

    @Test func updateOnlyReplacesSpecifiedKeys() async {
        var fetched: [TimeInterval?] = []
        let cache = PosterFrameCache { key in fetched.append(key.time); return nil }
        let url = URL(fileURLWithPath: "/tmp/First.mp4")
        let otherURL = URL(fileURLWithPath: "/tmp/Second.mp4")
        let old = PosterFrameCache.Key(url, 10)
        let otherFrame = PosterFrameCache.Key(url, 12)
        let otherFile = PosterFrameCache.Key(otherURL, 10)
        _ = await cache.thumbnail(for: old)
        _ = await cache.thumbnail(for: otherFrame)
        _ = await cache.thumbnail(for: otherFile)
        let keptFrame = cache.cached(otherFrame)
        let keptFile = cache.cached(otherFile)
        await cache.update(url, old: 10, new: nil)
        #expect(cache.cached(old) == nil)
        #expect(cache.cached(PosterFrameCache.Key(url, nil)) != nil)
        #expect(cache.cached(otherFrame) === keptFrame)
        #expect(cache.cached(otherFile) === keptFile)
        #expect(fetched.count == 4)
    }

    @Test func synchronousInvalidationRemovesNegativeResultsAndPreservesOtherFrames() async {
        var fetchCount = 0
        let cache = PosterFrameCache { _ in fetchCount += 1; return nil }
        let url = URL(fileURLWithPath: "/tmp/ChangedPoster.mp4")
        let old = PosterFrameCache.Key(url, 4)
        let new = PosterFrameCache.Key(url, 8)
        let other = PosterFrameCache.Key(url, 12)
        _ = await cache.thumbnail(for: old)
        _ = await cache.thumbnail(for: new)
        _ = await cache.thumbnail(for: other)
        let retained = cache.cached(other)
        #expect(fetchCount == 3)
        cache.invalidate(url, old: 4, new: 8)
        #expect(cache.cached(old) == nil)
        #expect(cache.cached(new) == nil)
        #expect(cache.cached(other) === retained)
        _ = await cache.thumbnail(for: new)
        #expect(fetchCount == 4)
    }

    @Test func sameTimeUpdateRefetches() async {
        var fetches = 0
        let cache = PosterFrameCache { _ in fetches += 1; return nil }
        let url = URL(fileURLWithPath: "/tmp/Refresh.mp4")
        _ = await cache.thumbnail(for: PosterFrameCache.Key(url, 3))
        await cache.update(url, old: 3, new: 3)
        #expect(fetches == 2)
    }
}
