import Foundation
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

/// A small aspect-fit poster covering the height of both lines of casting detail.
/// Quick Look receives the original image or a full-resolution extracted video frame.
public struct PosterThumbnail: View {
    let url: URL
    let time: TimeInterval?
    let directory: URL?
    let showPreview: (URL) -> Void

    @State private var thumbnail: CGImage?
    @State private var posterRevision = 0
    @Environment(\.displayScale) private var displayScale

    private let box = CGSize(width: 76, height: 46)

    public init(
		url: URL,
		time: TimeInterval?,
		directory: URL?,
		showPreview: @escaping (URL) -> Void)
	{
		self.url = url
		self.time = time
		self.directory = directory
		self.showPreview = showPreview
	}

    private func displaySize(for image: CGImage) -> CGSize {
        let scale = min(box.width / CGFloat(image.width), box.height / CGFloat(image.height))
        return CGSize(width: CGFloat(image.width) * scale,
                      height: CGFloat(image.height) * scale)
    }

    private var thumbnailTaskID: String {
        let timeComponent: String
        if let time {
            timeComponent = String(time)
        } else {
            timeComponent = "poster"
        }
        return "\(url.absoluteString)#\(timeComponent)#\(displayScale)#\(posterRevision)"
    }

    public var body: some View {
        HStack(spacing: 0) {
            if let thumbnail {
                Button {
                    Task { await preview() }
                } label: {
                    Image(decorative: thumbnail, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: displaySize(for: thumbnail).width,
                               height: displaySize(for: thumbnail).height)
                        .frame(width: box.width, height: box.height, alignment: .center)
                }
                .buttonStyle(.plain)
                .help("Quick Look full-size image")
            }
        }
        .task(id: thumbnailTaskID) {
            await loadThumbnail()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sbjPosterFrameDidChange)) { notification in
            guard let changedURL = notification.object as? URL,
                  changedURL.standardizedFileURL == url.standardizedFileURL else { return }
            posterRevision &+= 1
        }
    }

    @MainActor
    private func loadThumbnail() async {
        thumbnail = nil

        let access = directory?.startAccessingSecurityScopedResource() ?? false
        defer {
            if access {
                directory?.stopAccessingSecurityScopedResource()
            }
        }

        // The layout box is in points; the extractor expects pixel dimensions.
        // Request 2x/3x pixels on Retina devices to avoid blurry thumbnails.
        let pixelBox = CGSize(width: box.width * displayScale,
                              height: box.height * displayScale)
        thumbnail = await getPosterFrame(from: url, at: time, fitting: pixelBox)
    }

    @MainActor
    private func preview() async {
        let access = directory?.startAccessingSecurityScopedResource() ?? false
        defer { if access { directory?.stopAccessingSecurityScopedResource() } }
        if url.isImageMedia {
            // Quick Look needs access after this function returns. A temporary copy
            // avoids relying on a security scope that has already been released.
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("Casting-QuickLook-\(UUID().uuidString)")
                .appendingPathExtension(url.pathExtension)
            guard (try? FileManager.default.copyItem(at: url, to: destination)) != nil else { return }
            showPreview(destination)
            return
        }
        // Do not enlarge the small UI thumbnail: extract the original-size frame.
        guard let image = await getPosterFrame(from: url, at: time) else { return }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("Casting-QuickLook-\(UUID().uuidString)")
            .appendingPathExtension("png")
        guard let output = CGImageDestinationCreateWithURL(
            destination as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else { return }
        CGImageDestinationAddImage(output, image, nil)
        guard CGImageDestinationFinalize(output) else { return }
        showPreview(destination)
    }
}
