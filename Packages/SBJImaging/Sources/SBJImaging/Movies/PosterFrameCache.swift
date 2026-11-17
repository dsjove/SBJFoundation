import Foundation
import CoreGraphics
import Observation

/// The optional time is part of the identity. Nil means no frame, not frame zero.
@MainActor
@Observable
public final class PosterFrameCache {
    public final class Key: NSObject {
        public let url: URL
        public let time: TimeInterval?
        /// Explicit content replacement for the same URL and poster time.
        public let revision: UInt64

        public init(_ url: URL, _ time: TimeInterval?,
                    revision: UInt64 = 0) {
            self.url = url.standardizedFileURL
            self.time = time
            self.revision = revision
        }

        public override var hash: Int {
            var hasher = Hasher()
            hasher.combine(url)
            hasher.combine(time)
            hasher.combine(revision)
            return hasher.finalize()
        }

        public override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? Key else { return false }
            return url == other.url && time == other.time && revision == other.revision
        }
    }

    public final class Value: NSObject {
        public let image: CGImage?
        public let key: Key

        public init(_ image: CGImage?, key: Key) {
            self.image = image
            self.key = key
        }
    }

    /// Embedded artwork revisions are local to the cache. Observing this value
    /// causes only thumbnails for the changed movie to request new artwork.
    private var embeddedRevisions: [URL: UInt64] = [:]

    /// Identity used by a thumbnail. Explicit-time frames are independent of
    /// embedded poster replacement and therefore always use revision zero.
    public func key(for url: URL, at time: TimeInterval?) -> Key {
        let normalized = url.standardizedFileURL
        return Key(normalized, time,
                   revision: time == nil ? embeddedRevisions[normalized, default: 0] : 0)
    }

    /// Call only after an embedded poster is successfully written or cleared.
    /// Views observe key(for:at:) and refresh through their full key identity.
    public func embeddedPosterDidChange(at url: URL) {
        let normalized = url.standardizedFileURL
        let old = key(for: normalized, at: nil)
        images.removeObject(forKey: old)
        inFlight.removeValue(forKey: old)?.task.cancel()
        embeddedRevisions[normalized, default: 0] &+= 1
    }

    @ObservationIgnored private let images = NSCache<Key, Value>()
    /// One extraction per key, shared by simultaneous requesters.
    /// An invalidated request may finish, but cannot repopulate the cache.
    @ObservationIgnored private var inFlight: [Key: (id: UUID, task: Task<CGImage?, Never>)] = [:]
    @ObservationIgnored private let fetch: @MainActor (Key) async -> CGImage?

    public init(countLimit: Int = 320, totalCostLimit: Int = 120 * 1024 * 1024,
                fetch: @escaping @MainActor (Key) async -> CGImage?) {
        self.fetch = fetch
        images.countLimit = countLimit
        images.totalCostLimit = totalCostLimit
    }

    public func cached(_ key: Key) -> Value? {
        images.object(forKey: key)
    }

    /// Record that an explicitly invalid time has no poster. This caches a
    /// negative lookup without scheduling a frame extraction. In-flight work
    /// for this key cannot overwrite the negative entry.
    public func cacheMissingPoster(for key: Key) {
        inFlight.removeValue(forKey: key)?.task.cancel()
        images.setObject(Value(nil, key: key), forKey: key, cost: 1)
    }

    @discardableResult
    public func thumbnail(for key: Key) async -> Value {
        // Negative times are control sentinels, never valid extraction requests.
        // A cache eviction must not cause a negative-time frame to be fetched.
        if key.time.map({ $0 < 0 }) == true {
            if let existing = cached(key) { return existing }
            cacheMissingPoster(for: key)
            return Value(nil, key: key)
        }
        if let existing = cached(key) { return existing }
        let request: (id: UUID, task: Task<CGImage?, Never>)
        if let existingRequest = inFlight[key] {
            request = existingRequest
        } else {
            let newRequest = (id: UUID(), task: Task { await fetch(key) })
            inFlight[key] = newRequest
            request = newRequest
        }
        let image = await request.task.value
        // Invalidation may have started a new request while this one ran.
        // Return its result to its original waiter, but never cache stale data.
        guard inFlight[key]?.id == request.id else {
            return Value(image, key: key)
        }
        inFlight.removeValue(forKey: key)
        if let existing = cached(key) { return existing }
        // A cached Value with nil image is a negative result; a missing key
        // means no extraction has yet been requested.
        let value = Value(image, key: key)
        images.setObject(value, forKey: key, cost: image.map { $0.bytesPerRow * $0.height } ?? 1)
        return value
    }

    /// Invalidate synchronously on the main actor before publishing an observable
    /// timestamp change. Otherwise a SwiftUI thumbnail task can reuse the old
    /// cached (including nil-image) result before an asynchronous update runs.
    /// In-flight extractions for either key must not repopulate stale entries.
    public func invalidate(_ url: URL, old: TimeInterval?, new: TimeInterval?) {
        for key in [Key(url, old), Key(url, new)] {
            images.removeObject(forKey: key)
            inFlight.removeValue(forKey: key)?.task.cancel()
        }
    }

    /// Invalidate and prefetch when an operation explicitly requests a refreshed
    /// entry. Interactive timestamp edits instead use synchronous invalidation,
    /// letting the thumbnail view request its visible frame.
    public func update(_ url: URL, old: TimeInterval?, new: TimeInterval?) async {
        invalidate(url, old: old, new: new)
        _ = await thumbnail(for: Key(url, new))
    }
}

