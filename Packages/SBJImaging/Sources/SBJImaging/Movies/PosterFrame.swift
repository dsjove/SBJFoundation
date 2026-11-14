import Foundation
import CoreGraphics
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import SBJFileResources


/// Posted after embedded poster artwork has been successfully updated on disk.
/// The object is the affected movie's file URL.
public extension Notification.Name {
    static let sbjPosterFrameDidChange = Notification.Name("SBJImaging.posterFrameDidChange")
}

@MainActor
private func posterFrameDidChange(at url: URL) {
    NotificationCenter.default.post(name: .sbjPosterFrameDidChange, object: url.standardizedFileURL)
}


#if os(macOS)
import AppKit
#elseif os(iOS) || os(tvOS) || os(visionOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#endif

#if !os(watchOS)
import AVFoundation
#endif

// MARK: - Common API

/// A missing poster is represented by nil; failures to load or extract one throw.
public enum PosterFrameReadError: LocalizedError {
    case invalidTime
    case unsupportedURL
    case httpStatus(Int)
    case unreadableImage

    public var errorDescription: String? {
        switch self {
        case .invalidTime: "The movie frame time must be finite."
        case .unsupportedURL: "The URL does not identify a supported image or movie."
        case .httpStatus(let code): "The image server returned HTTP status \(code)."
        case .unreadableImage: "The image could not be decoded."
        }
    }
}

/// Policy for movie files without a specified time and without a saved poster.
/// The default respects an intentionally missing poster.
public enum MissingPosterBehavior: Sendable {
    case none
    case firstFrame
}


/// Returns the image itself for image URLs, or an extracted poster frame for videos.
/// When `time` is supplied for a video, extracts that frame (seconds) instead of poster artwork.
/// The `time` parameter is ignored for images.
/// `fitting` optionally scales either result to fit inside a pixel-size bounding box.
/// Aspect ratio is preserved, and smaller frames are not upscaled.
/// Supports local file URLs and HTTP(S) image URLs.
/// On watchOS, image URLs are supported; video frame extraction is unavailable.
public func getPosterFrame(
    from url: URL,
    at time: TimeInterval? = nil,
    fitting size: CGSize? = nil,
    ifMissingPoster missingPoster: MissingPosterBehavior = .none
) async throws -> CGImage? {

    // Videos must go through AVFoundation. ImageIO can return a container's
    // tiny preview image rather than a frame at the requested timestamp.
    #if !os(watchOS)
    if url.isMovieMedia {
        let asset = AVURLAsset(url: url)
        if let time {
            guard time.isFinite else { throw PosterFrameReadError.invalidTime }
            let bounded = await boundedPosterTime(time, in: asset)
            let frame = try await generateFrameAtTime(
                from: asset,
                at: CMTime(seconds: bounded, preferredTimescale: 600)
            )
            return fit(frame, within: size)
        }

        // Poster artwork is embedded in the movie. No timestamp or Finder icon is used.
        if let image = try await extractNativeEmbeddedPoster(from: url) {
            return fit(image, within: size)
        }

        if missingPoster == .firstFrame {
            let frame = try await generateFrameAtTime(from: asset, at: .zero)
            return fit(frame, within: size)
        }
        return nil
    }
    #endif

    // Still image input. No movie/poster metadata involved.
    if url.isFileURL {
        guard let image = loadLocalImage(from: url, fitting: size) else {
            throw PosterFrameReadError.unreadableImage
        }
        return image
    }
    if let scheme = url.scheme?.lowercased(),
       (scheme == "https" || scheme == "http"), isLikelyImageURL(url) {
        return try await loadRemoteImage(from: url, fitting: size)
    }
    throw PosterFrameReadError.unsupportedURL
}

/// Tests whether a movie advertises embedded poster artwork without decoding
/// image bytes, extracting a video frame, or exporting the movie.
///
/// This is a metadata-presence check, not a guarantee that the artwork can be
/// decoded. A movie with only video frames (and no embedded artwork) returns false.
/// The asset metadata lookup is asynchronous and may still require file I/O.
public func hasPosterFrame(from url: URL) async throws -> Bool {
    #if !os(watchOS)
    guard url.isMovieMedia else { return false }
    let asset = AVURLAsset(url: url)
    // Mirror the same metadata sources and priority used by
    // extractNativeEmbeddedPoster, without loading item values or image bytes.
    let metadata = try await asset.load(.metadata)
    if !quickTimePosterItems(in: metadata).isEmpty { return true }
    let common = try await asset.load(.commonMetadata)
    return !commonPosterItems(in: common).isEmpty
    #else
    return false
    #endif
}

// MARK: - Platform-specific UI wrappers

#if os(iOS) || os(tvOS) || os(visionOS)
func getPosterFrameAsUIImage(from url: URL, at time: TimeInterval? = nil, fitting size: CGSize? = nil,
                                   ifMissingPoster missingPoster: MissingPosterBehavior = .none) async throws -> UIImage? {
    guard let image = try await getPosterFrame(from: url, at: time, fitting: size, ifMissingPoster: missingPoster) else { return nil }
    return UIImage(cgImage: image)
}
#endif

#if os(macOS)
func getPosterFrameAsNSImage(from url: URL, at time: TimeInterval? = nil, fitting size: CGSize? = nil,
                                    ifMissingPoster missingPoster: MissingPosterBehavior = .none) async throws -> NSImage? {
    guard let image = try await getPosterFrame(from: url, at: time, fitting: size, ifMissingPoster: missingPoster) else { return nil }
    return NSImage(cgImage: image, size: CGSize(width: image.width, height: image.height))
}
#endif

/// Available on iOS, macOS, and watchOS without UIKit or AppKit conversions.
func getPosterFrameAsSwiftUIImage(from url: URL, at time: TimeInterval? = nil, fitting size: CGSize? = nil,
                                         ifMissingPoster missingPoster: MissingPosterBehavior = .none) async throws -> SwiftUI.Image? {
    guard let image = try await getPosterFrame(from: url, at: time, fitting: size, ifMissingPoster: missingPoster) else { return nil }
    return SwiftUI.Image(decorative: image, scale: 1)
}

// MARK: - Aspect-fit scaling

/// Returns pixels sized to fit inside `size` without distortion or upscaling.
/// Nil or invalid bounds leave the decoded frame unchanged.
private func fit(_ image: CGImage?, within size: CGSize?) -> CGImage? {
    guard let image else { return nil }
    guard let size,
          size.width.isFinite, size.height.isFinite,
          size.width >= 1, size.height >= 1 else { return image }

    let factor = min(1, size.width / CGFloat(image.width), size.height / CGFloat(image.height))
    guard factor < 1 else { return image }

    let width = max(1, Int((CGFloat(image.width) * factor).rounded()))
    let height = max(1, Int((CGFloat(image.height) * factor).rounded()))
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return image }

    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage() ?? image
}

// MARK: - Images

private func isLikelyImageURL(_ url: URL) -> Bool {
    let ext = url.pathExtension
    if ext.isEmpty { return true }
    return UTType(filenameExtension: ext)?.conforms(to: .image) == true
}

/// Decode through ImageIO and let its decoder downsample *before* creating
/// a CGImage. This avoids resampling the decoded pixel buffer in an RGB context
/// (which can produce degraded results with some image formats/color spaces).
/// Reject incomplete sources instead of displaying partial progressive images.
private func imageFromSource(_ source: CGImageSource, fitting size: CGSize?) -> CGImage? {
    guard CGImageSourceGetCount(source) > 0,
          CGImageSourceGetStatus(source) == .statusComplete,
          CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete else { return nil }

    let baseOptions: [CFString: Any] = [
        kCGImageSourceShouldCache: true,
        kCGImageSourceShouldCacheImmediately: true
    ]
    if let size, size.width.isFinite, size.height.isFinite,
       size.width >= 1, size.height >= 1 {
        let maxPixels = max(size.width, size.height).rounded(.up)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
    return CGImageSourceCreateImageAtIndex(source, 0, baseOptions as CFDictionary)
}

private func decodeImage(_ data: Data, fitting size: CGSize? = nil) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    return imageFromSource(source, fitting: size)
}

private func loadLocalImage(from url: URL, fitting size: CGSize? = nil) -> CGImage? {
    if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
       let image = imageFromSource(source, fitting: size) {
        return image
    }
    // Some file types (notably WebP on certain OS versions) are supported by
    // the platform image loader even when ImageIO cannot decode them directly.
    #if os(macOS)
    if let image = NSImage(contentsOf: url),
       let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        return fit(cgImage, within: size)
    }
    #elseif os(iOS) || os(tvOS) || os(visionOS)
    if let image = UIImage(contentsOfFile: url.path), let cgImage = image.cgImage {
        return fit(cgImage, within: size)
    }
    #endif
    return nil
}

private func loadRemoteImage(from url: URL, fitting size: CGSize? = nil) async throws -> CGImage? {
    let (data, response) = try await URLSession.shared.data(from: url)
    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
        throw PosterFrameReadError.httpStatus(http.statusCode)
    }
    guard let image = decodeImage(data, fitting: size) else {
        throw PosterFrameReadError.unreadableImage
    }
    return image
}

#if !os(watchOS)
// MARK: - Videos

// Both the inexpensive presence check and the artwork reader use precisely
// these keys. Neither helper decodes or validates an image.
private func quickTimePosterItems(in metadata: [AVMetadataItem]) -> [AVMetadataItem] {
    metadata.filter { $0.identifier == .quickTimeMetadataArtwork }
}

private func commonPosterItems(in metadata: [AVMetadataItem]) -> [AVMetadataItem] {
    AVMetadataItem.metadataItems(
        from: metadata, withKey: AVMetadataKey.commonKeyArtwork, keySpace: .common
    )
}

// Reads embedded artwork (when present), not a guaranteed video poster frame.
private func extractNativeEmbeddedPoster(from url: URL) async throws -> CGImage? {
    let asset = AVURLAsset(url: url)
    do {
        let metadata = try await asset.load(.metadata)
        let common = try await asset.load(.commonMetadata)
        let items = quickTimePosterItems(in: metadata) + commonPosterItems(in: common)

        guard let item = items.first else { return nil }
        let value = try await item.load(.value)

        if let data = value as? Data {
            return decodeImage(data)
        }
        if let values = value as? [String: Any],
           let time = values["time"] as? CMTime {
            return try await generateFrameAtTime(from: asset, at: time)
        }
    } catch {
        throw error
    }
    return nil
}

/// Bound an explicit time to the available movie timeline. With an unknown
/// duration we can still safely enforce the lower bound.
private func boundedPosterTime(_ time: TimeInterval, in asset: AVAsset) async -> TimeInterval {
    let minimum = max(0, time)
    guard let duration = try? await asset.load(.duration),
          duration.isNumeric else { return minimum }
    let seconds = CMTimeGetSeconds(duration)
    guard seconds.isFinite, seconds > 0 else { return minimum }
    return min(minimum, max(0, seconds - 0.001))
}

private func generateFrameAtTime(
    from asset: AVAsset,
    at time: CMTime
) async throws -> CGImage {
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero

    for await result in generator.images(for: [time]) {
        return try result.image
    }

    throw NSError(
        domain: "SBJImaging.PosterFrame",
        code: 1,
        userInfo: [
            NSLocalizedDescriptionKey: "No frame was generated."
        ]
    )
}
#endif

#if os(macOS) || os(iOS) || os(visionOS)
public enum PosterFrameWriteResult {
    case embeddedArtwork
}

public enum PosterFrameWriteError: LocalizedError {
    case invalidMovieURL, invalidTime, frameUnavailable, cannotEncodeFrame, cannotWriteArtwork
    case exportUnavailable, unsupportedExportFormat, metadataReadFailed(String)
    case exportFailed(String), verificationFailed(String), replacementFailed(String)
    public var errorDescription: String? {
        switch self {
        case .invalidMovieURL: return "Select a local movie file (.mov, .mp4, or .m4v)."
        case .invalidTime: return "The supplied movie time must be finite."
        case .frameUnavailable: return "No frame was available at the requested time."
        case .cannotEncodeFrame: return "Could not encode the selected frame."
        case .cannotWriteArtwork: return "Could not write the poster artwork in the movie."
        case .exportUnavailable: return "AVFoundation cannot create a passthrough export for this movie."
        case .unsupportedExportFormat: return "AVFoundation cannot export this movie in its original format."
        case .metadataReadFailed(let reason): return "Could not read movie metadata: \(reason)"
        case .exportFailed(let reason): return "Movie metadata export failed: \(reason)"
        case .verificationFailed(let reason): return "Exported movie verification failed: \(reason)"
        case .replacementFailed(let reason): return "Could not replace the original movie: \(reason)"
        }
    }
}

/// Extracts the full-resolution movie frame at the given time and embeds it as JPEG artwork.
/// All expensive work runs outside the main actor.
@discardableResult
public func setPosterFrame(
    from url: URL,
    at time: TimeInterval
) async throws -> PosterFrameWriteResult {
    guard url.isMovieMedia else { throw PosterFrameWriteError.invalidMovieURL }
    guard time.isFinite else { throw PosterFrameWriteError.invalidTime }
    let asset = AVURLAsset(url: url)
    let bounded = await boundedPosterTime(time, in: asset)
    let frame: CGImage
    do {
        frame = try await generateFrameAtTime(
            from: asset,
            at: CMTime(seconds: bounded, preferredTimescale: 600)
        )
    } catch {
        throw PosterFrameWriteError.frameUnavailable
    }
    return try await embedPosterFrame(frame, in: url, asset: asset)
}

/// Embeds the supplied full-resolution image as JPEG artwork in the movie.
/// No frame extraction, timestamp metadata, Finder icons, or sidecars are used.
@discardableResult
public func setPosterFrame(
    from url: URL,
    image: CGImage
) async throws -> PosterFrameWriteResult {
    guard url.isMovieMedia else { throw PosterFrameWriteError.invalidMovieURL }
    let asset = AVURLAsset(url: url)
    return try await embedPosterFrame(image, in: url, asset: asset)
}

// Inspect each container metadata format, not only AVAsset.metadata. In some
// QuickTime files artwork is exposed through format-specific keys and/or a
// common-key projection, neither of which is safe to ignore when clearing.
struct PosterMetadataSnapshot {
    let items: [AVMetadataItem]
    let commonItems: [AVMetadataItem]
    let byFormat: [(format: AVMetadataFormat, items: [AVMetadataItem])]

    var containsArtwork: Bool {
        items.contains(where: isPosterArtworkItem)
            || commonItems.contains(where: isPosterArtworkItem)
            || byFormat.contains { $0.items.contains(where: isPosterArtworkItem) }
    }
}

/// Detect AVFoundation's normalized identifiers as well as artwork-specific
/// container keys. Avoid filtering unrelated binary metadata by data type.
func isPosterArtworkItem(_ item: AVMetadataItem) -> Bool {
    if item.identifier == .quickTimeMetadataArtwork || item.commonKey == .commonKeyArtwork {
        return true
    }
    let identifier = item.identifier?.rawValue.lowercased() ?? ""
    let key = (item.key as? String)?.lowercased() ?? ""
    return identifier.contains("artwork")
        || identifier.contains("coverart")
        || identifier.contains("covr")
        || identifier.contains("attachedpicture")
        || key == "covr" || key == "apic"
}

private func posterMetadataIdentity(_ item: AVMetadataItem) -> String {
    // Used only to avoid re-adding the same identifier from AVAsset.metadata
    // and a format-specific collection. Keep distinct localized variants.
    "\(item.keySpace?.rawValue ?? "")|\(item.identifier?.rawValue ?? "")|\(item.locale?.identifier ?? "")"
}

private func loadPosterMetadataSnapshot(from asset: AVAsset) async throws -> PosterMetadataSnapshot {
    let items = try await asset.load(.metadata)
    let commonItems = try await asset.load(.commonMetadata)
    let formats = try await asset.load(.availableMetadataFormats)
    var byFormat: [(format: AVMetadataFormat, items: [AVMetadataItem])] = []
    for format in formats {
        byFormat.append((format, try await asset.loadMetadata(for: format)))
    }
    return PosterMetadataSnapshot(items: items, commonItems: commonItems, byFormat: byFormat)
}


/// Prepare a complete explicit metadata replacement. AVFoundation's exported
/// top-level metadata may omit keys surfaced by a container-specific format.
/// Do not introduce duplicates when a key is already in the main collection.
func filteredPosterMetadata(_ snapshot: PosterMetadataSnapshot) -> [AVMetadataItem] {
    let legacyTimestampID = AVMetadataIdentifier(rawValue: "mdta/com.example.Casting.posterTime")
    var kept = snapshot.items.filter {
        !isPosterArtworkItem($0) && $0.identifier != legacyTimestampID
    }
    // Count occurrences rather than using a Set: multiple values can share
    // the same identifier (e.g. multilingual or repeated metadata entries).
    var existingCounts: [String: Int] = [:]
    for item in kept { existingCounts[posterMetadataIdentity(item), default: 0] += 1 }
    for entry in snapshot.byFormat {
        var seenInFormat: [String: Int] = [:]
        for item in entry.items where !isPosterArtworkItem(item)
            && item.identifier != legacyTimestampID {
            let identity = posterMetadataIdentity(item)
            seenInFormat[identity, default: 0] += 1
            if seenInFormat[identity, default: 0] > existingCounts[identity, default: 0] {
                kept.append(item)
                existingCounts[identity, default: 0] += 1
            }
        }
    }
    return kept
}

/// Removes embedded poster artwork while preserving the movie's other metadata
/// and tracks. Uses the same staged passthrough export as poster updates.
public func clearPosterFrame(from url: URL) async throws {
    guard url.isMovieMedia else { throw PosterFrameWriteError.invalidMovieURL }
    let asset = AVURLAsset(url: url)
    // A failed metadata read is not proof that the artwork is absent.
    let snapshot: PosterMetadataSnapshot
    do { snapshot = try await loadPosterMetadataSnapshot(from: asset) }
    catch { throw PosterFrameWriteError.metadataReadFailed(error.localizedDescription) }
    if !snapshot.containsArtwork { return }
    try await writePosterMetadata(in: url, asset: asset, artwork: nil)
    await MainActor.run { posterFrameDidChange(at: url) }
}

private func embedPosterFrame(
    _ image: CGImage, in url: URL, asset: AVURLAsset
) async throws -> PosterFrameWriteResult {
    guard let data = jpegData(for: image) else {
        throw PosterFrameWriteError.cannotEncodeFrame
    }
    try await writePosterMetadata(in: url, asset: asset, artwork: data)
    await MainActor.run { posterFrameDidChange(at: url) }
    return .embeddedArtwork
}

private func jpegData(for image: CGImage) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
    CGImageDestinationAddImage(destination, image,
        [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
    return CGImageDestinationFinalize(destination) ? data as Data : nil
}

/// Exports embedded JPEG artwork using a passthrough session. Only poster
/// metadata is changed; other metadata is preserved. Verifies the staged movie
/// before replacing the original file.
private func writePosterMetadata(
    in url: URL, asset: AVURLAsset, artwork: Data?
) async throws {
    let format: AVFileType
    switch url.pathExtension.lowercased() {
    case "mov": format = .mov
    case "mp4": format = .mp4
    case "m4v": format = .m4v
    default:
        throw PosterFrameWriteError.invalidMovieURL
    }
    guard let session = AVAssetExportSession(
        asset: asset, presetName: AVAssetExportPresetPassthrough
    ) else {
        throw PosterFrameWriteError.exportUnavailable
    }
    guard session.supportedFileTypes.contains(format) else {
        throw PosterFrameWriteError.unsupportedExportFormat
    }
    let snapshot: PosterMetadataSnapshot
    do { snapshot = try await loadPosterMetadataSnapshot(from: asset) }
    catch {
        throw PosterFrameWriteError.metadataReadFailed(error.localizedDescription)
    }
    // Explicit replacement, including format-specific keys, not merely the
    // generic AVAsset.metadata projection.
    var items = filteredPosterMetadata(snapshot)
    if let artwork {
        let item = AVMutableMetadataItem()
        item.identifier = .quickTimeMetadataArtwork
        item.value = artwork as NSData
        item.dataType = "com.apple.metadata.datatype.JPEG"
        items.append(item)
    }
    // AVAssetExportSession interprets an empty metadata array as permission to
    // copy the source asset's metadata. When artwork was the only metadata,
    // our filtered list is empty, so the artwork survives the export.
    // Force an explicit, non-empty replacement with a blank QuickTime comment.
    // This intentionally introduces a harmless blank comment; it is preferable
    // to silently retaining poster artwork. The staged output is still verified
    // and NEVER replaces the original if artwork survives.
    if artwork == nil && items.isEmpty {
        let sentinel = AVMutableMetadataItem()
        sentinel.identifier = AVMetadataIdentifier(rawValue: "mdta/com.apple.quicktime.comment")
        sentinel.value = " " as NSString
        items.append(sentinel)
    }
    session.metadata = items

    let stagingURL = url.deletingLastPathComponent()
        .appendingPathComponent(".CastingPoster-\(UUID().uuidString).\(url.pathExtension)")
    defer { try? FileManager.default.removeItem(at: stagingURL) }
    do {
        try await session.export(to: stagingURL, as: format)
    } catch {
        throw PosterFrameWriteError.exportFailed(error.localizedDescription)
    }
    if artwork != nil {
        let verified: CGImage?
        do { verified = try await extractNativeEmbeddedPoster(from: stagingURL) }
        catch { throw PosterFrameWriteError.verificationFailed(error.localizedDescription) }
        guard verified != nil else {
            throw PosterFrameWriteError.verificationFailed("Selected poster artwork was not present or decodable in the exported movie.")
        }
    } else {
        // Verification includes format-specific metadata (the original failure
        // survived a filter based solely on top-level/common metadata).
        let stagedAsset = AVURLAsset(url: stagingURL)
        let staged: PosterMetadataSnapshot
        do { staged = try await loadPosterMetadataSnapshot(from: stagedAsset) }
        catch { throw PosterFrameWriteError.verificationFailed(error.localizedDescription) }
        guard !staged.containsArtwork else {
            throw PosterFrameWriteError.verificationFailed(
                "The exported movie still contains poster artwork."
            )
        }
    }
    do {
        _ = try FileManager.default.replaceItemAt(url, withItemAt: stagingURL,
                                                  backupItemName: nil, options: [])
    } catch {
        throw PosterFrameWriteError.replacementFailed(error.localizedDescription)
    }
}
#endif

#if os(tvOS) || os(watchOS)
/// Retains consistent setter signatures on platforms without writable movies.
public enum PosterFrameWriteResult { case embeddedArtwork }

public enum PosterFrameWriteError: LocalizedError {
    case unsupportedPlatform
    public var errorDescription: String? { "Movie poster modification is not available on this platform." }
}

public func clearPosterFrame(from url: URL) async throws {
    throw PosterFrameWriteError.unsupportedPlatform
}

@discardableResult
public func setPosterFrame(from url: URL, at time: TimeInterval) async throws -> PosterFrameWriteResult {
    throw PosterFrameWriteError.unsupportedPlatform
}

@discardableResult
public func setPosterFrame(from url: URL, image: CGImage) async throws -> PosterFrameWriteResult {
    throw PosterFrameWriteError.unsupportedPlatform
}
#endif
