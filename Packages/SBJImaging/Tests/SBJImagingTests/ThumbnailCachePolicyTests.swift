import SBJImaging
import Foundation
import Testing
@testable import SBJImaging

@MainActor
struct ThumbnailCachePolicyTests {
    @Test func keyContainsFullURLAndOptionalTime() {
        let a = URL(fileURLWithPath: "/media/A.mp4")
        let b = URL(fileURLWithPath: "/media/B.mp4")
        #expect(PosterFrameCache.Key(a, 2) == PosterFrameCache.Key(a, 2))
        #expect(PosterFrameCache.Key(a, 2) != PosterFrameCache.Key(a, 3))
        #expect(PosterFrameCache.Key(a, 2) != PosterFrameCache.Key(b, 2))
        #expect(PosterFrameCache.Key(a, nil) != PosterFrameCache.Key(a, 0))
        #expect(PosterFrameCache.Key(a, nil) == PosterFrameCache.Key(a, nil))
    }

}
