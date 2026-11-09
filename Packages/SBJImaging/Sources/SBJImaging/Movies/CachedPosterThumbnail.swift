import SwiftUI
import CoreGraphics

/// Shows a cached thumbnail. The caller owns the tap behavior and preview route.
public struct CachedPosterThumbnail: View {
    public let url: URL
    public let time: TimeInterval?
    public let cache: PosterFrameCache
    public let onPreview: (PosterFrameCache.Key) -> Void

    private let size: CGSize
    private let placeholderSymbol: String

    public init(url: URL, time: TimeInterval?, cache: PosterFrameCache,
                size: CGSize = CGSize(width: 76, height: 54),
                placeholderSymbol: String = "film",
                onPreview: @escaping (PosterFrameCache.Key) -> Void) {
        self.url = url
        self.time = time
        self.cache = cache
        self.size = size
        self.placeholderSymbol = placeholderSymbol
        self.onPreview = onPreview
    }

    @State private var lastKey: PosterFrameCache.Key?
    @State private var current: CGImage?

    private var key: PosterFrameCache.Key { PosterFrameCache.Key(url, time) }

    public var body: some View {
        Button { onPreview(key) } label: {
            Group {
                if let current {
                    Image(decorative: current, scale: 1)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: placeholderSymbol)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.secondary)
                        .padding(10)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help("Quick Look")
        .task(id: key) {
            let requested = key
            lastKey = requested
            current = cache.cached(requested)?.image
            let entry = await cache.thumbnail(for: requested)
            guard !Task.isCancelled, lastKey == requested else { return }
            current = entry.image
        }
    }
}
