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

    @Test func nonfiniteTimestampsAreStableMissingFrameKeys() async {
        var fetches = 0
        let cache = PosterFrameCache { _ in fetches += 1; return nil }
        let url = URL(fileURLWithPath: "/tmp/invalid-time.mov")
        for invalid in [Double.nan, Double.infinity, -Double.infinity] {
            let key = PosterFrameCache.Key(url, invalid)
            #expect(key.time == -1)
            _ = await cache.thumbnail(for: key)
            _ = await cache.thumbnail(for: PosterFrameCache.Key(url, invalid))
            #expect(cache.cached(key) != nil)
        }
        #expect(fetches == 0)
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

@MainActor
struct PosterFramePolicyTests {
    @Test func revisionOnlySeparatesReplacedEmbeddedPosters() async {
        let url = URL(fileURLWithPath: "/tmp/same-movie.mov")
        let movie = PosterFrameCache.Key(url, nil)
        let castingFrame = PosterFrameCache.Key(url, 2)
        let changedEmbeddedPoster = PosterFrameCache.Key(url, nil, revision: 1)
        #expect(movie != castingFrame)
        #expect(movie != changedEmbeddedPoster)
        #expect(castingFrame == PosterFrameCache.Key(url, 2, revision: 0))
    }
}

@MainActor
struct PosterFrameRevisionTests {
    @Test func replacingEmbeddedArtworkRequestsNewImageForSameURLAndTime() async {
        var fetches = 0
        let cache = PosterFrameCache { _ in fetches += 1; return nil }
        let url = URL(fileURLWithPath: "/tmp/replaced-artwork.mov")
        let first = PosterFrameCache.Key(url, nil, revision: 0)
        let replaced = PosterFrameCache.Key(url, nil, revision: 1)
        _ = await cache.thumbnail(for: first)
        _ = await cache.thumbnail(for: first)
        _ = await cache.thumbnail(for: replaced)
        _ = await cache.thumbnail(for: replaced)
        #expect(first != replaced)
        #expect(fetches == 2)
    }
}

@MainActor
struct EmbeddedPosterChangeTests {
    @Test func replacingOrClearingPosterRefreshesOnlyNilTimeAndDropsOldCacheEntry() async {
        var fetched: [PosterFrameCache.Key] = []
        let cache = PosterFrameCache { key in
            fetched.append(key)
            return nil
        }
        let url = URL(fileURLWithPath: "/tmp/film.mov")
        let other = URL(fileURLWithPath: "/tmp/other.mov")
        let original = cache.key(for: url, at: nil)
        let frame = cache.key(for: url, at: 2)
        let otherPoster = cache.key(for: other, at: nil)
        _ = await cache.thumbnail(for: original)
        _ = await cache.thumbnail(for: frame)
        _ = await cache.thumbnail(for: otherPoster)

        cache.embeddedPosterDidChange(at: url)
        let replaced = cache.key(for: url, at: nil)
        #expect(replaced != original)
        #expect(cache.cached(original) == nil)
        #expect(cache.key(for: url, at: 2) == frame)
        #expect(cache.key(for: other, at: nil) == otherPoster)
        #expect(cache.cached(frame) != nil)
        #expect(cache.cached(otherPoster) != nil)

        _ = await cache.thumbnail(for: replaced)
        #expect(fetched.count == 4)
        cache.embeddedPosterDidChange(at: url) // clear
        let cleared = cache.key(for: url, at: nil)
        #expect(cleared != replaced)
        #expect(cache.cached(replaced) == nil)
        _ = await cache.thumbnail(for: cleared)
        #expect(fetched.count == 5)
    }
}
