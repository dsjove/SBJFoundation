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
        let image = await fetch(key)
        // An update may have populated the key while the fetch was running.
        if let existing = cached(key) { return existing }
        let value = Value(image, key: key)
        images.setObject(value, forKey: key, cost: image.map { $0.bytesPerRow * $0.height } ?? 1)
        return value
    }

    /// Replace one timestamp, without invalidating other frames for this file.
    public func update(_ url: URL, old: TimeInterval?, new: TimeInterval?) async {
        let oldKey = Key(url, old)
        let newKey = Key(url, new)
        images.removeObject(forKey: oldKey)
        // Force a fresh thumbnail even when old and new times are equal.
        images.removeObject(forKey: newKey)
        _ = await thumbnail(for: newKey)
    }
}

