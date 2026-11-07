import SwiftUI
import CoreGraphics
#if os(macOS)
import AppKit
#endif

/// A reusable slideshow of images supplied by the caller. The component has no
/// knowledge of media files, castings, actors, or application-wide state.
public struct ImageSlideshow: View {
    let count: Int
    let slideTitle: (Int) -> String
    let fetchImage: @MainActor (Int) async -> CGImage?
    let onClose: () -> Void

    @State private var index = 0
    @State private var cachedImages: [Int: CGImage] = [:]
    @State private var unavailableIndices: Set<Int> = []
    @State private var isPlaying = true
    @State private var isLoading = false
    @State private var fullscreen = false
    #if os(macOS)
    @State private var hostingWindow: NSWindow?
    #endif

    public init(
        count: Int,
        slideTitle: @escaping (Int) -> String = { _ in "" },
        fetchImage: @escaping @MainActor (Int) async -> CGImage?,
        onClose: @escaping () -> Void = {}
    ) {
        self.count = count
        self.slideTitle = slideTitle
        self.fetchImage = fetchImage
        self.onClose = onClose
    }

    /// Convenience initializer for an already fetched collection of CGImages.
    /// The caller can use compactMap to omit missing images before presenting.
    public init(images: [CGImage], titles: [String] = [], onClose: @escaping () -> Void = {}) {
        self.init(count: images.count, slideTitle: { index in
            titles.indices.contains(index) ? titles[index] : ""
        }, fetchImage: { index in
            guard images.indices.contains(index) else { return nil }
            return images[index]
        }, onClose: onClose)
    }

    public var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ZStack {
                    Color.black
                    if let image = cachedImages[index] {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    } else if isLoading {
                        ProgressView().tint(.white)
                    } else if !hasAvailableSlides {
                        ContentUnavailableView("No images", systemImage: "photo")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            }
            HStack(spacing: 14) {
                Button(action: onClose) { Image(systemName: "xmark") }
                    .accessibilityLabel("Close slideshow")
                Button { advance(by: -1) } label: { Image(systemName: "chevron.left") }
                    .disabled(availableCount < 2)
                Button { isPlaying.toggle() } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }
                .disabled(availableCount < 2)
                Button { advance(by: 1) } label: { Image(systemName: "chevron.right") }
                    .disabled(availableCount < 2)
                Spacer(minLength: 0)
                // One slide caption, displayed in the chrome instead of on top of the image.
                Text(count > 0 ? slideTitle(index) : "")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Slide title")
                Spacer(minLength: 0)
                Button { toggleFullscreen() } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .accessibilityLabel("Toggle fullscreen")
                .help("Full screen")
                Text("\(count == 0 ? 0 : index + 1) / \(count)")
                    .monospacedDigit()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.black)
        }
        .background(Color.black.ignoresSafeArea())
        #if os(macOS)
        .background(SlideshowWindowReader(window: $hostingWindow))
        #else
        .fullScreenCover(isPresented: $fullscreen) {
            slideshowFullscreenContent
        }
        #endif
        .task(id: index) { await loadCurrentImage() }
        .task(id: isPlaying) {
            guard isPlaying, availableCount > 1 else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(4)) }
                catch { return }
                guard !Task.isCancelled else { return }
                advance(by: 1)
            }
        }
        #if os(macOS)
        .onKeyPress(.leftArrow) { advance(by: -1); return .handled }
        .onKeyPress(.rightArrow) { advance(by: 1); return .handled }
        .onKeyPress(.space) { isPlaying.toggle(); return .handled }
        #endif
    }

    #if os(iOS) || os(visionOS)
    private var slideshowFullscreenContent: some View {
        ImageSlideshow(
            count: count,
            slideTitle: slideTitle,
            fetchImage: fetchImage,
            onClose: { fullscreen = false }
        )
        .overlay(alignment: .topTrailing) {
            Button("Exit fullscreen", systemImage: "arrow.down.right.and.arrow.up.left") {
                fullscreen = false
            }
            .labelStyle(.iconOnly)
            .padding(12)
        }
    }
    #endif

    private func toggleFullscreen() {
        #if os(macOS)
        hostingWindow?.toggleFullScreen(nil)
        #else
        fullscreen = true
        #endif
    }

    private var availableCount: Int { max(0, count - unavailableIndices.count) }
    private var hasAvailableSlides: Bool { availableCount > 0 }

    private func advance(by step: Int) {
        guard count > 0, hasAvailableSlides else { return }
        for distance in 1...count {
            let candidate = (index + step * distance % count + count) % count
            if !unavailableIndices.contains(candidate) {
                index = candidate
                return
            }
        }
    }

    @MainActor
    private func loadCurrentImage() async {
        guard (0..<count).contains(index), cachedImages[index] == nil else { return }
        isLoading = true
        let selectedIndex = index
        let result = await fetchImage(selectedIndex)
        guard !Task.isCancelled else { return }
        isLoading = false
        if let result {
            cachedImages[selectedIndex] = result
        } else {
            unavailableIndices.insert(selectedIndex)
            advance(by: 1) // Skip missing images; never display an invalid/black slide.
        }
    }
}

#if os(macOS)
private struct SlideshowWindowReader: NSViewRepresentable {
    @Binding var window: NSWindow?
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { window = view.window }
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { window = view.window }
    }
}
#endif
