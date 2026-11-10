import Foundation
import CoreGraphics

/// The optional time is part of the identity. Nil means no frame, not frame zero.
@MainActor
public final class PosterFrameCache {
    public final class Key: NSObject {
        public let url: URL
        public let time: TimeInterval?

        public init(_ url: URL, _ time: TimeInterval?) {
            self.url = url.standardizedFileURL
            self.time = time
        }

        public override var hash: Int {
            var hasher = Hasher()
            hasher.combine(url)
            hasher.combine(time)
            return hasher.finalize()
        }

        public override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? Key else { return false }
            return url == other.url && time == other.time
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

    private let images = NSCache<Key, Value>()
    /// One extraction per key, shared by simultaneous requesters.
    /// An invalidated request may finish, but cannot repopulate the cache.
    private var inFlight: [Key: (id: UUID, task: Task<CGImage?, Never>)] = [:]
    private let fetch: @MainActor (Key) async -> CGImage?

    public init(countLimit: Int = 320, totalCostLimit: Int = 120 * 1024 * 1024,
                fetch: @escaping @MainActor (Key) async -> CGImage?) {
        self.fetch = fetch
        images.countLimit = countLimit
        images.totalCostLimit = totalCostLimit
    }

    public func cached(_ key: Key) -> Value? {
        images.object(forKey: key)
    }

    @discardableResult
    public func thumbnail(for key: Key) async -> Value {
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
        let oldKey = Key(url, old)
        let newKey = Key(url, new)
        images.removeObject(forKey: oldKey)
        inFlight.removeValue(forKey: oldKey)?.task.cancel()
        images.removeObject(forKey: newKey)
        inFlight.removeValue(forKey: newKey)?.task.cancel()
    }

    /// Invalidate and prefetch when an operation explicitly requests a refreshed
    /// entry. Interactive timestamp edits instead use synchronous invalidation,
    /// letting the thumbnail view request its visible frame.
    public func update(_ url: URL, old: TimeInterval?, new: TimeInterval?) async {
        invalidate(url, old: old, new: new)
        _ = await thumbnail(for: Key(url, new))
    }
}

