import Foundation
import SwiftUI
import Testing
@testable import SBJImaging

@MainActor
struct CachedPosterThumbnailAPITests {
    @Test func readOnlyAndBindingInitializersRemainDistinct() {
        let cache = PosterFrameCache { _ in nil }
        let url = URL(fileURLWithPath: "/tmp/sample.mov")
        _ = CachedPosterThumbnail(url: url, time: TimeInterval(2), cache: cache) { _ in }

        var selected: TimeInterval? = nil
        let binding = Binding<TimeInterval?>(
            get: { selected },
            set: { selected = $0 }
        )
        _ = CachedPosterThumbnail(url: url, time: binding, cache: cache,
                                  noPosterTime: -1) { _ in }
    }
}
