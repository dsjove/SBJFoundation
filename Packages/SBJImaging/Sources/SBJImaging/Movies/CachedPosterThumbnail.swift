import SwiftUI
import CoreGraphics

/// A cached thumbnail. When `noPosterTime` and `onToggleNoPoster` are supplied,
/// the thumbnail also owns the nil / no-poster tap interaction. Storage remains
/// the client's responsibility: the callback saves the new time before the
/// client publishes its observable model.
public struct CachedPosterThumbnail: View {
    public let url: URL
    public let time: TimeInterval?
    public let cache: PosterFrameCache
    public let onPreview: (PosterFrameCache.Key) -> Void

    private let size: CGSize
    private let placeholderSymbol: String
    private let editableTime: Binding<TimeInterval?>?
    private let noPosterTime: TimeInterval

    /// Read-only thumbnail. Negative timestamps are not interpreted as an app
    /// sentinel by this initializer; clients should supply a valid media time.
    public init(url: URL, time: TimeInterval?, cache: PosterFrameCache,
                size: CGSize = CGSize(width: 76, height: 54),
                placeholderSymbol: String = "film",
                onPreview: @escaping (PosterFrameCache.Key) -> Void) {
        self.url = url
        self.time = time
        self.cache = cache
        self.size = size
        self.placeholderSymbol = placeholderSymbol
        self.editableTime = nil
        self.noPosterTime = -1
        self.onPreview = onPreview
    }

    /// Editable poster timestamp. Negative times display film.fill and a tap
    /// clears the value. Nil displays the ordinary placeholder and a tap writes
    /// the client's no-poster sentinel through this binding.
    /// The binding setter is responsible for persistence and error reporting.
    public init(url: URL, time: Binding<TimeInterval?>, cache: PosterFrameCache,
                size: CGSize = CGSize(width: 76, height: 54),
                placeholderSymbol: String = "film",
                noPosterTime: TimeInterval = -1,
                onPreview: @escaping (PosterFrameCache.Key) -> Void) {
        self.url = url
        self.time = time.wrappedValue
        self.cache = cache
        self.size = size
        self.placeholderSymbol = placeholderSymbol
        self.editableTime = time
        self.noPosterTime = noPosterTime
        self.onPreview = onPreview
    }

    @State private var current: CGImage?

    // Read the binding on every body evaluation. The editable initializer's
    // snapshot is not authoritative after a user edit or a cache eviction.
    private var displayedTime: TimeInterval? {
        if let editableTime { return editableTime.wrappedValue }
        return time
    }
    private var key: PosterFrameCache.Key { PosterFrameCache.Key(url, displayedTime) }
    private var isInvalidTime: Bool {
        editableTime != nil && displayedTime.map { $0 < 0 } == true
    }

    public var body: some View {
        Button(action: tapped) {
            Group {
                if isInvalidTime {
                    Image(systemName: "film.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.secondary)
                        .padding(10)
                } else if let current {
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
            .contentShape(Rectangle())
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(tapHelp)
        // The URL and poster time completely identify supported image content.
        // A changed key starts a new task; no NotificationCenter or client-owned
        // revision is needed. Key.revision is reserved for future replacements.
        .task(id: key) {
            let requested = key
            if isInvalidTime {
                current = nil
                cache.cacheMissingPoster(for: requested)
                return
            }
            current = cache.cached(requested)?.image
            let entry = await cache.thumbnail(for: requested)
            guard !Task.isCancelled, key == requested else { return }
            current = entry.image
        }
    }

    private var tapHelp: String {
        guard editableTime != nil else { return "Quick Look" }
        if isInvalidTime { return "Clear no-poster mark" }
        if displayedTime == nil { return "Mark no poster" }
        return "Quick Look"
    }

    private func tapped() {
        if let editableTime {
            if isInvalidTime {
                editableTime.wrappedValue = nil
                return
            }
            if displayedTime == nil {
                editableTime.wrappedValue = noPosterTime
                return
            }
        }
        onPreview(key)
    }
}
