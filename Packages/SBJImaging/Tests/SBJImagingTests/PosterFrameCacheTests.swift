import Foundation
import Testing
@testable import SBJImaging

@MainActor
struct PosterFrameCacheTests {
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
