import Foundation
import CoreGraphics
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import SBJFileResources
import os

private let posterLogger = Logger(subsystem: "SBJImaging", category: "PosterFrame")

/// Posted after poster metadata has been successfully updated on disk.
/// The object is the affected movie's file URL (not a Finder icon URL).
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

        // 1. Saved frame timestamp. 2. Embedded poster image.
        // Never read a Finder icon: it is a low-resolution square intended
        // only for Finder, not a poster suitable for display.
        if let saved = await getPosterFrameTime(from: url) {
            let bounded = await boundedPosterTime(saved, in: asset)
            do {
                let frame = try await generateFrameAtTime(
                    from: asset,
                    at: CMTime(seconds: bounded, preferredTimescale: 600)
                )
                posterLogger.info("GET source=embeddedTimestamp at=\(bounded), size=\(imageDimensions(frame), privacy: .public)")
                return fit(frame, within: size)
            } catch {
                posterLogger.error("GET timestamp frame failed: \(error.localizedDescription, privacy: .public); trying embedded artwork")
            }
        } else {
            posterLogger.debug("GET timestamp metadata absent; trying embedded artwork")
        }

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
        posterLogger.notice("GET no readable poster (Finder icon intentionally ignored)")
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

#if !os(watchOS)
/// Reads the poster timestamp written by Casting. Artwork alone has no standard
/// recoverable presentation time, so absence of this value is not an error.
func getPosterFrameTime(from url: URL) async -> TimeInterval? {
    let asset = AVURLAsset(url: url)
    let items: [AVMetadataItem]
    do { items = try await asset.load(.metadata) }
    catch {
        posterLogger.error("TIMESTAMP unable to load metadata: \(error.localizedDescription, privacy: .public)")
        return nil
    }
    let timestampID = "mdta/com.example.Casting.posterTime"
    for item in items where item.identifier?.rawValue == timestampID {
        if let value = try? await item.load(.stringValue),
           let seconds = Double(value), seconds.isFinite {
            posterLogger.debug("TIMESTAMP found value=\(seconds)")
            return seconds
        }
        posterLogger.warning("TIMESTAMP tag exists but has no valid numeric value")
    }
    posterLogger.debug("TIMESTAMP tag absent")
    return nil
}
#endif

#if os(macOS) || os(iOS) || os(visionOS)
public enum PosterFrameWriteResult {
    case embeddedTimestamp, embeddedArtwork, filesystemThumbnail, cleared
}

public enum PosterFrameWriteError: LocalizedError {
    case invalidMovieURL, invalidTime, frameUnavailable, cannotEncodeFrame, cannotWriteArtwork
    public var errorDescription: String? {
        switch self {
        case .invalidMovieURL: return "Select a local movie file (.mov, .mp4, or .m4v)."
        case .invalidTime: return "The supplied movie time must be finite."
        case .frameUnavailable: return "No frame was available at the requested time."
        case .cannotEncodeFrame: return "Could not encode the selected frame."
        case .cannotWriteArtwork: return "Could not persist a poster timestamp or embedded poster image."
        }
    }
}

/// Time wins over image when both are specified. A timestamp is stored when
/// the container supports it; otherwise the selected frame is embedded as JPEG
/// artwork if possible. On macOS a separate Finder icon is always attempted.
/// Neither the getter nor setter uses JPEG sidecars or reads Finder icons.
@MainActor
@discardableResult
public func setPosterFrame(
    from url: URL,
    at time: TimeInterval? = nil,
    image: CGImage? = nil
) async throws -> PosterFrameWriteResult {
    posterLogger.notice("SET file=\(url.lastPathComponent, privacy: .public), time=\(time.map(String.init(describing:)) ?? "none", privacy: .public), image=\(image.map(imageDimensions) ?? "none", privacy: .public)")
    guard url.isMovieMediaFile else { throw PosterFrameWriteError.invalidMovieURL }
    if let time, !time.isFinite { throw PosterFrameWriteError.invalidTime }

    if time == nil && image == nil {
        let metadataCleared = await writePosterMetadata(in: url, timestamp: nil, artwork: nil)
        #if os(macOS)
        let iconCleared = NSWorkspace.shared.setIcon(nil, forFile: url.path, options: [])
        posterLogger.notice("SET clear: metadata=\(metadataCleared), FinderIcon=\(iconCleared)")
        #else
        posterLogger.notice("SET clear: metadata=\(metadataCleared)")
        #endif
        guard metadataCleared else { throw PosterFrameWriteError.cannotWriteArtwork }
        posterFrameDidChange(at: url)
        return .cleared
    }

    let selectedTime: TimeInterval?
    if let time {
        let asset = AVURLAsset(url: url)
        selectedTime = await boundedPosterTime(time, in: asset)
        posterLogger.info("SET timestamp requested=\(time), clamped=\(selectedTime ?? 0)")
    } else {
        selectedTime = nil
    }

    // The selected high-quality frame is used for the Finder icon and image
    // metadata fallback. Frame generation does not use a thumbnail constraint.
    let frame: CGImage
    if let selectedTime {
        let asset = AVURLAsset(url: url)
        do {
            frame = try await generateFrameAtTime(
                from: asset,
                at: CMTime(seconds: selectedTime, preferredTimescale: 600)
            )
            posterLogger.info("SET source=movieFrame size=\(imageDimensions(frame), privacy: .public)")
        } catch {
            posterLogger.error("SET frame extraction failed: \(error.localizedDescription, privacy: .public)")
            throw PosterFrameWriteError.frameUnavailable
        }
    } else if let image {
        frame = image
        posterLogger.info("SET source=suppliedImage size=\(imageDimensions(frame), privacy: .public)")
    } else { throw PosterFrameWriteError.frameUnavailable }

    // For timestamp requests, don't create/encode JPEG artwork if the custom
    // metadata can be stored and read back successfully.
    var savedTimestamp = false
    if let selectedTime {
        // The current QuickTime custom mdta key does not survive MP4/M4V
        // passthrough exports. Avoid an expensive, doomed whole-file rewrite.
        // MOV retains the timestamp-first attempt and read-back verification.
        switch url.pathExtension.lowercased() {
        case "mov":
            savedTimestamp = await writePosterMetadata(
                in: url, timestamp: selectedTime, artwork: nil
            )
            posterLogger.notice("SET timestamp metadata result=\(savedTimestamp)")
        case "mp4", "m4v":
            posterLogger.notice("SET timestamp metadata skipped for MP4/M4V; writing embedded artwork instead")
        default:
            posterLogger.notice("SET no timestamp metadata strategy for this extension")
        }
    }

    var savedArtwork = false
    if !savedTimestamp {
        guard let data = jpegData(for: frame) else {
            posterLogger.error("SET unable to encode full-resolution frame")
            throw PosterFrameWriteError.cannotEncodeFrame
        }
        posterLogger.info("SET JPEG artwork sourceSize=\(imageDimensions(frame), privacy: .public), bytes=\(data.count)")
        savedArtwork = await writePosterMetadata(in: url, timestamp: nil, artwork: data)
        posterLogger.notice("SET embedded artwork result=\(savedArtwork)")
    }

    #if os(macOS)
    let finderIcon = finderIconImage(from: frame)
    let iconWritten = NSWorkspace.shared.setIcon(finderIcon, forFile: url.path, options: [])
    posterLogger.notice("SET Finder icon (display-only)=\(iconWritten), iconSize=512x512")
    #else
    let iconWritten = false
    #endif

    if savedTimestamp {
        posterFrameDidChange(at: url)
        return .embeddedTimestamp
    }
    if savedArtwork {
        posterFrameDidChange(at: url)
        return .embeddedArtwork
    }
    if iconWritten {
        posterLogger.error("SET only Finder icon succeeded; no retrievable poster was saved")
    }
    throw PosterFrameWriteError.cannotWriteArtwork
}

private func jpegData(for image: CGImage) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
    CGImageDestinationAddImage(destination, image,
        [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
    return CGImageDestinationFinalize(destination) ? data as Data : nil
}

#if os(macOS)
/// Finder needs a square icon. This is NEVER used for app poster retrieval.
/// Letterbox (rather than crop) so ultrawide frames remain recognizable.
private func finderIconImage(from frame: CGImage) -> NSImage {
    let side = 512
    guard let context = CGContext(
        data: nil, width: side, height: side,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return NSImage(cgImage: frame,
                       size: NSSize(width: frame.width, height: frame.height))
    }
    let ratio = min(CGFloat(side) / CGFloat(frame.width),
                    CGFloat(side) / CGFloat(frame.height))
    let width = CGFloat(frame.width) * ratio
    let height = CGFloat(frame.height) * ratio
    context.setFillColor(CGColor(gray: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: side, height: side))
    context.interpolationQuality = .high
    context.draw(frame, in: CGRect(x: (CGFloat(side) - width) / 2,
                                   y: (CGFloat(side) - height) / 2,
                                   width: width, height: height))
    let iconCG = context.makeImage() ?? frame
    return NSImage(cgImage: iconCG, size: NSSize(width: side, height: side))
}
#endif

/// Rewrites metadata using AVFoundation passthrough and verifies the staged
/// result BEFORE replacing the source. Only the existing poster timestamp and
/// QuickTime artwork entries are changed; other metadata is retained.
/// MP4 support is attempted only when AVFoundation reports an MP4 export type.
@MainActor
private func writePosterMetadata(
    in url: URL, timestamp: TimeInterval?, artwork: Data?
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
    let asset = AVURLAsset(url: url)
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
    let timestampID = AVMetadataIdentifier(rawValue: "mdta/com.example.Casting.posterTime")
    let originalItems: [AVMetadataItem]
    do { originalItems = try await asset.load(.metadata) }
    catch {
        posterLogger.error("METADATA original metadata read failed: \(error.localizedDescription, privacy: .public)")
        return false
    }
    var items = originalItems.filter {
        $0.identifier != timestampID && $0.identifier != .quickTimeMetadataArtwork
    }
    if let timestamp {
        let item = AVMutableMetadataItem()
        item.identifier = timestampID
        item.value = String(format: "%.6f", timestamp) as NSString
        item.dataType = "com.apple.metadata.datatype.UTF8"
        items.append(item)
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
        try await session.export(to: stagingURL, as: format)
        let writtenAsset = AVURLAsset(url: stagingURL)
        if let timestamp {
            guard let writtenTime = await getPosterFrameTime(from: stagingURL),
                  abs(writtenTime - timestamp) < 0.000_002 else {
                posterLogger.error("METADATA timestamp missing/incorrect after export; refusing replacement")
                return false
            }
        }
        if artwork != nil {
            // Presence alone is not enough; ensure we can decode the saved image.
            guard await extractNativeEmbeddedPoster(from: stagingURL) != nil else {
                posterLogger.error("METADATA exported artwork cannot be decoded; refusing replacement")
                return false
            }
        }
        if timestamp == nil && artwork == nil {
            let written = try await writtenAsset.load(.metadata)
            guard !written.contains(where: {
                $0.identifier == timestampID || $0.identifier == .quickTimeMetadataArtwork
            }) else {
                posterLogger.error("METADATA failed to clear poster tags")
                return false
            }
        }
        _ = try FileManager.default.replaceItemAt(url, withItemAt: stagingURL,
                                                  backupItemName: nil, options: [])
        posterLogger.notice("METADATA persisted format=\(url.pathExtension, privacy: .public), timestamp=\(timestamp != nil), artwork=\(artwork != nil)")
        return true
    } catch {
        posterLogger.error("METADATA export/replacement failed: \(error.localizedDescription, privacy: .public)")
        return false
    }
}
#endif

#if os(tvOS) || os(watchOS)
/// Retains a consistent library signature on platforms without writable movie files.
enum PosterFrameWriteResult { case embeddedTimestamp, embeddedArtwork, filesystemThumbnail, cleared }

enum PosterFrameWriteError: LocalizedError {
    case unsupportedPlatform
    var errorDescription: String? { "Movie poster modification is not available on this platform." }
}

@MainActor
@discardableResult
func setPosterFrame(from url: URL, at time: TimeInterval? = nil,
                    image: CGImage? = nil) async throws -> PosterFrameWriteResult {
    throw PosterFrameWriteError.unsupportedPlatform
}
#endif

#if os(watchOS)
func getPosterFrameTime(from url: URL) async -> TimeInterval? { nil }
#endif
