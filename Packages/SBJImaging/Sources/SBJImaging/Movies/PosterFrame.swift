import Foundation
import CoreGraphics
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import SBJFileResources
import os
import QuartzCore

private let posterLogger = Logger(subsystem: "SBJImaging", category: "PosterFrame")
private func posterElapsed(_ start: CFTimeInterval) -> String {
    String(format: "%.3f", CACurrentMediaTime() - start)
}

/// Posted after embedded poster artwork has been successfully updated on disk.
/// The object is the affected movie's file URL.
public extension Notification.Name {
    static let sbjPosterFrameDidChange = Notification.Name("SBJImaging.posterFrameDidChange")
}

@MainActor
private func posterFrameDidChange(at url: URL) {
    NotificationCenter.default.post(name: .sbjPosterFrameDidChange, object: url.standardizedFileURL)
}

private func imageDimensions(_ image: CGImage) -> String { "\(image.width)x\(image.height)" }

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
) async -> CGImage? {
    posterLogger.info("GET file=\(url.lastPathComponent, privacy: .public), timestamp=\(time.map(String.init(describing:)) ?? "none", privacy: .public)")

    // Videos must go through AVFoundation. ImageIO can return a container's
    // tiny preview image rather than a frame at the requested timestamp.
    #if !os(watchOS)
    if url.isMovieMediaFile {
        let asset = AVURLAsset(url: url)
        if let time {
            guard time.isFinite else {
                posterLogger.error("GET invalid explicit timestamp")
                return nil
            }
            let bounded = await boundedPosterTime(time, in: asset)
            do {
                let frame = try await generateFrameAtTime(
                    from: asset,
                    at: CMTime(seconds: bounded, preferredTimescale: 600)
                )
                posterLogger.info("GET source=explicitTimestamp at=\(bounded), size=\(imageDimensions(frame), privacy: .public)")
                return fit(frame, within: size)
            } catch {
                posterLogger.error("GET explicit timestamp extraction failed: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }

        // Poster artwork is embedded in the movie. No timestamp or Finder icon is used.
        if let image = await extractNativeEmbeddedPoster(from: url) {
            posterLogger.info("GET source=embeddedArtwork size=\(imageDimensions(image), privacy: .public)")
            return fit(image, within: size)
        }
        posterLogger.debug("GET embedded artwork absent or undecodable")

        if missingPoster == .firstFrame {
            do {
                let frame = try await generateFrameAtTime(from: asset, at: .zero)
                posterLogger.info("GET source=firstFrame size=\(imageDimensions(frame), privacy: .public)")
                return fit(frame, within: size)
            } catch {
                posterLogger.error("GET first-frame extraction failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        posterLogger.notice("GET no readable embedded poster")
        return nil
    }
    #endif

    // Still image input. No movie/poster metadata involved.
    if url.isFileURL {
        let image = loadLocalImage(from: url, fitting: size)
        if let image { posterLogger.info("GET source=imageFile size=\(imageDimensions(image), privacy: .public)") }
        return image
    }
    if let scheme = url.scheme?.lowercased(),
       (scheme == "https" || scheme == "http"), isLikelyImageURL(url) {
        return await loadRemoteImage(from: url, fitting: size)
    }
    return nil
}

/// Tests whether a movie advertises embedded poster artwork without decoding
/// image bytes, extracting a video frame, or exporting the movie.
///
/// This is a metadata-presence check, not a guarantee that the artwork can be
/// decoded. A movie with only video frames (and no embedded artwork) returns false.
/// The asset metadata lookup is asynchronous and may still require file I/O.
public func hasPosterFrame(from url: URL) async -> Bool {
    #if !os(watchOS)
    guard url.isMovieMediaFile else { return false }
    let asset = AVURLAsset(url: url)
    do {
        let metadata = try await asset.load(.metadata)
        if metadata.contains(where: { $0.identifier == .quickTimeMetadataArtwork }) {
            return true
        }
        let common = try await asset.load(.commonMetadata)
        return !AVMetadataItem.metadataItems(
            from: common, withKey: AVMetadataKey.commonKeyArtwork, keySpace: .common
        ).isEmpty
    } catch {
        posterLogger.debug("POSTER presence lookup failed file=\(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        return false
    }
    #else
    return false
    #endif
}

// MARK: - Platform-specific UI wrappers

#if os(iOS) || os(tvOS) || os(visionOS)
func getPosterFrameAsUIImage(from url: URL, at time: TimeInterval? = nil, fitting size: CGSize? = nil,
                                   ifMissingPoster missingPoster: MissingPosterBehavior = .none) async -> UIImage? {
    guard let image = await getPosterFrame(from: url, at: time, fitting: size, ifMissingPoster: missingPoster) else { return nil }
    return UIImage(cgImage: image)
}
#endif

#if os(macOS)
func getPosterFrameAsNSImage(from url: URL, at time: TimeInterval? = nil, fitting size: CGSize? = nil,
                                    ifMissingPoster missingPoster: MissingPosterBehavior = .none) async -> NSImage? {
    guard let image = await getPosterFrame(from: url, at: time, fitting: size, ifMissingPoster: missingPoster) else { return nil }
    return NSImage(cgImage: image, size: CGSize(width: image.width, height: image.height))
}
#endif

/// Available on iOS, macOS, and watchOS without UIKit or AppKit conversions.
func getPosterFrameAsSwiftUIImage(from url: URL, at time: TimeInterval? = nil, fitting size: CGSize? = nil,
                                         ifMissingPoster missingPoster: MissingPosterBehavior = .none) async -> SwiftUI.Image? {
    guard let image = await getPosterFrame(from: url, at: time, fitting: size, ifMissingPoster: missingPoster) else { return nil }
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
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return imageFromSource(source, fitting: size)
}

private func loadRemoteImage(from url: URL, fitting size: CGSize? = nil) async -> CGImage? {
    guard let (data, response) = try? await URLSession.shared.data(from: url) else {
        return nil
    }
    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
        return nil
    }
    return decodeImage(data, fitting: size)
}

#if !os(watchOS)
// MARK: - Videos

// Reads embedded artwork (when present), not a guaranteed video poster frame.
private func extractNativeEmbeddedPoster(from url: URL) async -> CGImage? {
    let asset = AVURLAsset(url: url)
    do {
        let metadata = try await asset.load(.metadata)
        let common = try await asset.load(.commonMetadata)
        let items = metadata.filter { $0.identifier == .quickTimeMetadataArtwork } +
            AVMetadataItem.metadataItems(from: common,
                withKey: AVMetadataKey.commonKeyArtwork, keySpace: .common)

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
        return nil
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
    public var errorDescription: String? {
        switch self {
        case .invalidMovieURL: return "Select a local movie file (.mov, .mp4, or .m4v)."
        case .invalidTime: return "The supplied movie time must be finite."
        case .frameUnavailable: return "No frame was available at the requested time."
        case .cannotEncodeFrame: return "Could not encode the selected frame."
        case .cannotWriteArtwork: return "Could not embed the poster artwork in the movie."
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
    guard url.isFileURL && url.isMovieMediaFile else { throw PosterFrameWriteError.invalidMovieURL }
    guard time.isFinite else { throw PosterFrameWriteError.invalidTime }

    let started = CACurrentMediaTime()
    posterLogger.notice("SET begin source=timestamp file=\(url.lastPathComponent, privacy: .public)")
    let asset = AVURLAsset(url: url)
    let bounded = await boundedPosterTime(time, in: asset)
    posterLogger.notice("SET bounded time elapsed=\(posterElapsed(started), privacy: .public)s")
    let frame: CGImage
    do {
        frame = try await generateFrameAtTime(
            from: asset,
            at: CMTime(seconds: bounded, preferredTimescale: 600)
        )
    } catch {
        posterLogger.error("SET frame extraction failed: \(error.localizedDescription, privacy: .public)")
        throw PosterFrameWriteError.frameUnavailable
    }
    posterLogger.notice("SET extracted at=\(bounded), size=\(imageDimensions(frame), privacy: .public), elapsed=\(posterElapsed(started), privacy: .public)s")
    return try await embedPosterFrame(frame, in: url, asset: asset)
}

/// Embeds the supplied full-resolution image as JPEG artwork in the movie.
/// No frame extraction, timestamp metadata, Finder icons, or sidecars are used.
@discardableResult
public func setPosterFrame(
    from url: URL,
    image: CGImage
) async throws -> PosterFrameWriteResult {
    guard url.isFileURL && url.isMovieMediaFile else { throw PosterFrameWriteError.invalidMovieURL }
    posterLogger.notice("SET begin source=image file=\(url.lastPathComponent, privacy: .public)")
    let asset = AVURLAsset(url: url)
    return try await embedPosterFrame(image, in: url, asset: asset)
}

/// Removes embedded poster artwork while preserving the movie's other metadata
/// and tracks. Uses the same staged passthrough export as poster updates.
public func clearPosterFrame(from url: URL) async throws {
    guard url.isFileURL && url.isMovieMediaFile else { throw PosterFrameWriteError.invalidMovieURL }
    let asset = AVURLAsset(url: url)
    guard await writePosterMetadata(in: url, asset: asset, artwork: nil) else {
        throw PosterFrameWriteError.cannotWriteArtwork
    }
    await MainActor.run { posterFrameDidChange(at: url) }
}

private func embedPosterFrame(
    _ image: CGImage, in url: URL, asset: AVURLAsset
) async throws -> PosterFrameWriteResult {
    let started = CACurrentMediaTime()
    guard let data = jpegData(for: image) else {
        throw PosterFrameWriteError.cannotEncodeFrame
    }
    posterLogger.notice("SET JPEG encoded sourceSize=\(imageDimensions(image), privacy: .public), bytes=\(data.count), elapsed=\(posterElapsed(started), privacy: .public)s")
    guard await writePosterMetadata(in: url, asset: asset, artwork: data) else {
        throw PosterFrameWriteError.cannotWriteArtwork
    }
    posterLogger.notice("SET metadata committed elapsed=\(posterElapsed(started), privacy: .public)s")
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
) async -> Bool {
    let format: AVFileType
    switch url.pathExtension.lowercased() {
    case "mov": format = .mov
    case "mp4": format = .mp4
    case "m4v": format = .m4v
    default:
        posterLogger.error("METADATA unsupported file extension")
        return false
    }
    guard let session = AVAssetExportSession(
        asset: asset, presetName: AVAssetExportPresetPassthrough
    ) else {
        posterLogger.warning("METADATA no passthrough export session")
        return false
    }
    guard session.supportedFileTypes.contains(format) else {
        posterLogger.warning("METADATA format not supported by passthrough export: \(url.pathExtension, privacy: .public)")
        return false
    }
    let started = CACurrentMediaTime()
    posterLogger.notice("METADATA begin source=\(url.lastPathComponent, privacy: .public)")
    let originalItems: [AVMetadataItem]
    do { originalItems = try await asset.load(.metadata) }
    catch {
        posterLogger.error("METADATA original metadata read failed: \(error.localizedDescription, privacy: .public)")
        return false
    }
    posterLogger.notice("METADATA loaded source items=\(originalItems.count), elapsed=\(posterElapsed(started), privacy: .public)s")
    // Remove legacy Casting timestamp and previous artwork entries, preserving
    // every other metadata item.
    let legacyTimestampID = AVMetadataIdentifier(rawValue: "mdta/com.example.Casting.posterTime")
    var items = originalItems.filter {
        $0.identifier != legacyTimestampID
            && $0.identifier != .quickTimeMetadataArtwork
            && $0.commonKey != .commonKeyArtwork
    }
    if let artwork {
        let item = AVMutableMetadataItem()
        item.identifier = .quickTimeMetadataArtwork
        item.value = artwork as NSData
        item.dataType = "com.apple.metadata.datatype.JPEG"
        items.append(item)
    }
    session.metadata = items

    let stagingURL = url.deletingLastPathComponent()
        .appendingPathComponent(".CastingPoster-\(UUID().uuidString).\(url.pathExtension)")
    defer { try? FileManager.default.removeItem(at: stagingURL) }
    do {
        posterLogger.notice("METADATA export starting elapsed=\(posterElapsed(started), privacy: .public)s")
        try await session.export(to: stagingURL, as: format)
        posterLogger.notice("METADATA export completed elapsed=\(posterElapsed(started), privacy: .public)s")
        if artwork != nil {
            guard await extractNativeEmbeddedPoster(from: stagingURL) != nil else {
                posterLogger.error("METADATA exported artwork cannot be decoded; refusing replacement")
                return false
            }
        } else {
            guard !(await hasPosterFrame(from: stagingURL)) else {
                posterLogger.error("METADATA exported movie still contains artwork; refusing replacement")
                return false
            }
        }
        posterLogger.notice("METADATA verification completed elapsed=\(posterElapsed(started), privacy: .public)s")
        _ = try FileManager.default.replaceItemAt(url, withItemAt: stagingURL,
                                                  backupItemName: nil, options: [])
        posterLogger.notice("METADATA embedded artwork persisted format=\(url.pathExtension, privacy: .public), elapsed=\(posterElapsed(started), privacy: .public)s")
        return true
    } catch {
        posterLogger.error("METADATA export/replacement failed: \(error.localizedDescription, privacy: .public)")
        return false
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
