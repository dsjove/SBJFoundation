import SwiftUI
import Observation
import CoreGraphics

/// App-owned slideshow sessions. Sessions retain image providers, not decoded
/// image collections, and are dropped when their presentation closes.
@MainActor
@Observable
public final class ImageSlideshowStore {
    /// Supplied by the application registering its WindowGroup.
    public let sceneID: String

    public init(sceneID: String) {
        self.sceneID = sceneID
    }

    public struct Session {
        public let count: Int
        public let slideTitle: (Int) -> String
        public let fetchImage: @MainActor (Int) async -> CGImage?

        public init(
            count: Int,
            slideTitle: @escaping (Int) -> String,
            fetchImage: @escaping @MainActor (Int) async -> CGImage?
        ) {
            self.count = count
            self.slideTitle = slideTitle
            self.fetchImage = fetchImage
        }
    }

    public private(set) var sessions: [UUID: Session] = [:]
    /// Fallback presentation, owned by the app root rather than a recyclable list row.
    public private(set) var sheetID: UUID?

    public func presentSheet(_ id: UUID) { sheetID = id }


    @discardableResult
    public func open(
        count: Int,
        slideTitle: @escaping (Int) -> String = { _ in "" },
        fetchImage: @escaping @MainActor (Int) async -> CGImage?
    ) -> UUID {
        let id = UUID()
        sessions[id] = Session(count: count, slideTitle: slideTitle, fetchImage: fetchImage)
        return id
    }

    /// Convenience for callers that already own a decoded collection.
    @discardableResult
    public func open(images: [CGImage], titles: [String] = []) -> UUID {
        open(
            count: images.count,
            slideTitle: { index in titles.indices.contains(index) ? titles[index] : "" },
            fetchImage: { index in images.indices.contains(index) ? images[index] : nil }
        )
    }

    public func close(_ id: UUID) {
        sessions[id] = nil
        if sheetID == id { sheetID = nil }
    }
}

#if os(macOS) || os(iOS) || os(visionOS)
public struct SlideshowWindowContent: View {
    private let id: UUID
    private let session: ImageSlideshowStore.Session
    private let store: ImageSlideshowStore

    public init(id: UUID, session: ImageSlideshowStore.Session, store: ImageSlideshowStore) {
        self.id = id
        self.session = session
        self.store = store
    }
    @Environment(\.dismissWindow) private var dismissWindow

    public var body: some View {
        ImageSlideshow(
            count: session.count,
            slideTitle: session.slideTitle,
            fetchImage: session.fetchImage
        ) {
            dismissWindow(id: store.sceneID, value: id)
            store.close(id)
        }
        .onDisappear { store.close(id) }
    }
}
#endif
