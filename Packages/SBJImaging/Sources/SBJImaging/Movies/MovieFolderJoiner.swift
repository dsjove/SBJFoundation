import Foundation
import AVFoundation
import CoreMedia
import CoreGraphics
import UniformTypeIdentifiers

/// Creates a single, chaptered QuickTime file from the immediate movie children of a folder.
/// Shared across macOS, iOS/iPadOS, Mac Catalyst, and visionOS.
/// The source media is never modified. All work is initiated with a user-selected folder URL.
@MainActor
public enum MovieFolderJoiner {
    public enum JoinError: LocalizedError {
        case noMovies
        case outputExists(String)
        case badVideo(String)
        case unsupportedExport
        case chapterWrite(String)
        case cannotSaveInFolder(String)

        public var errorDescription: String? {
            switch self {
            case .noMovies: "The folder contains no supported movie files."
            case .outputExists(let name): "The output ‘\(name)’ already exists. Move or rename it before joining."
            case .badVideo(let name): "Cannot read video dimensions or duration for ‘\(name)’."
            case .unsupportedExport: "AVFoundation cannot export this combination of movie formats as QuickTime."
            case .chapterWrite(let detail): "Could not create QuickTime chapter markers: \(detail)"
            case .cannotSaveInFolder(let detail): "Could not save the joined movie in the selected folder: \(detail)"
            }
        }
    }

    struct Clip {
        let url: URL
        let asset: AVURLAsset
        let video: AVAssetTrack
        let audio: AVAssetTrack?
        let duration: CMTime
        let naturalSize: CGSize
        let preferredTransform: CGAffineTransform
        let displayRect: CGRect
    }

    /// Computes the oriented video bounds (handles portrait video and rotation matrices).
    static func orientedBounds(size: CGSize, transform: CGAffineTransform) -> CGRect {
        CGRect(origin: .zero, size: size).applying(transform).standardized
    }

    /// Aspect-fit, enlarging source frames to the canvas without distortion or downscaling.
    /// The joiner chooses canvas dimensions at least as large as every oriented source.
    static func aspectFitTransform(size: CGSize, preferredTransform: CGAffineTransform,
                                   canvas: CGSize) -> CGAffineTransform {
        let bounds = orientedBounds(size: size, transform: preferredTransform)
        // The output canvas is the largest oriented source width and height, so
        // both ratios are >= 1. Unlike min(1, ...), this allows smaller clips
        // to grow as much as possible while preserving their aspect ratios.
        let factor = min(canvas.width / bounds.width, canvas.height / bounds.height)
        let centerX = (canvas.width - bounds.width * factor) / 2
        let centerY = (canvas.height - bounds.height * factor) / 2
        return preferredTransform
            .concatenating(CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY))
            .concatenating(CGAffineTransform(scaleX: factor, y: factor))
            .concatenating(CGAffineTransform(translationX: centerX, y: centerY))
    }

    static func destinationURL(for directory: URL) -> URL {
        directory.appendingPathComponent(directory.lastPathComponent).appendingPathExtension("mov")
    }

    public static func join(directory: URL,
                     update: @escaping @MainActor (String) -> Void) async throws -> URL {
        let sourceScope = directory.startAccessingSecurityScopedResource()
        defer {
            if sourceScope { directory.stopAccessingSecurityScopedResource() }
        }

        // One user-selected security scope covers both input clips and the output.
        let final = Self.destinationURL(for: directory)
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: final.path) else {
            throw JoinError.outputExists(final.lastPathComponent)
        }
        let contents = try fileManager.contentsOfDirectory(at: directory,
                                                           includingPropertiesForKeys: [.isRegularFileKey],
                                                           options: [.skipsHiddenFiles])
        let urls = contents.filter { url in
            (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true &&
            (UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) == true ||
             ["mov", "mp4", "m4v", "avi", "mkv", "mpg", "mpeg"].contains(url.pathExtension.lowercased()))
        }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        guard !urls.isEmpty else { throw JoinError.noMovies }

        var clips: [Clip] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
        for (index, url) in urls.enumerated() {
            update("Inspecting \(index + 1)/\(urls.count): \(url.lastPathComponent)")
            let asset = AVURLAsset(url: url)
            guard let video = try await asset.loadTracks(withMediaType: .video).first else {
                throw JoinError.badVideo(url.lastPathComponent)
            }
            let duration = try await asset.load(.duration)
            let size = try await video.load(.naturalSize)
            let transform = try await video.load(.preferredTransform)
            let bounds = Self.orientedBounds(size: size, transform: transform)
            guard duration.isNumeric, duration.seconds > 0,
                  bounds.width > 0, bounds.height > 0,
                  bounds.width.isFinite, bounds.height.isFinite else {
                throw JoinError.badVideo(url.lastPathComponent)
            }
            let audio = try await asset.loadTracks(withMediaType: .audio).first
            width = max(width, bounds.width)
            height = max(height, bounds.height)
            clips.append(Clip(url: url, asset: asset, video: video, audio: audio,
                              duration: duration, naturalSize: size, preferredTransform: transform,
                              displayRect: bounds))
        }
        // Video encoders typically require even canvas dimensions.
        let canvas = CGSize(width: ceil(width / 2) * 2, height: ceil(height / 2) * 2)
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video,
                                                            preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio,
                                                            preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw JoinError.unsupportedExport
        }
        var cursor = CMTime.zero
        var chapterStarts: [(name: String, start: CMTime, duration: CMTime)] = []
        var instructions: [AVMutableVideoCompositionInstruction] = []
        for (index, clip) in clips.enumerated() {
            let range = CMTimeRange(start: .zero, duration: clip.duration)
            try videoTrack.insertTimeRange(range, of: clip.video, at: cursor)
            if let audio = clip.audio {
                try audioTrack.insertTimeRange(range, of: audio, at: cursor)
            } else {
                audioTrack.insertEmptyTimeRange(CMTimeRange(start: cursor, duration: clip.duration))
            }
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: cursor, duration: clip.duration)
            let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            layer.setTransform(Self.aspectFitTransform(size: clip.naturalSize,
                                                  preferredTransform: clip.preferredTransform,
                                                  canvas: canvas), at: cursor)
            instruction.layerInstructions = [layer]
            instructions.append(instruction)
            chapterStarts.append(("Chapter \(index + 1)", cursor, clip.duration))
            cursor = CMTimeAdd(cursor, clip.duration)
        }
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = canvas
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.instructions = instructions

        guard let session = AVAssetExportSession(asset: composition,
                                                  presetName: AVAssetExportPresetHighestQuality),
              session.supportedFileTypes.contains(.mov) else {
            throw JoinError.unsupportedExport
        }
        session.videoComposition = videoComposition
        // Render in the app's own writable temporary directory. The source folder
        // is only needed for reading, and must not require write permission.
        let temporary = fileManager.temporaryDirectory
        let intermediate = temporary.appendingPathComponent("\(UUID().uuidString)-joined.mov")
        let chaptered = temporary.appendingPathComponent("\(UUID().uuidString)-chapters.mov")
        defer {
            try? fileManager.removeItem(at: intermediate)
            try? fileManager.removeItem(at: chaptered)
        }
        update("Rendering \(clips.count) clips (\(Int(canvas.width)) × \(Int(canvas.height))…")
        try await session.export(to: intermediate, as: .mov)
        update("Writing \(chapterStarts.count) QuickTime chapters…")
        try await Self.writeChapters(from: intermediate, to: chaptered, chapters: chapterStarts)
        // Never replace a previous output, even if one appeared while exporting.
        guard !fileManager.fileExists(atPath: final.path) else {
            throw JoinError.outputExists(final.lastPathComponent)
        }
        do {
            try fileManager.moveItem(at: chaptered, to: final)
        } catch {
            throw JoinError.cannotSaveInFolder("Target: \(final.path). \(error.localizedDescription)")
        }
        update("Created \(final.lastPathComponent) with \(chapterStarts.count) chapters")
        return final
    }

    /// QuickTime chapters are a disabled text sample track associated with the video track
    /// using the `chap` track reference. Ordinary timed metadata alone does not create chapters.
    private static func writeChapters(from source: URL, to destination: URL,
                                      chapters: [(name: String, start: CMTime, duration: CMTime)]) async throws {
        let sourceMovie = AVMovie(url: source, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let movie = try AVMutableMovie(settingsFrom: sourceMovie,
                                       options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        movie.defaultMediaDataStorage = AVMediaDataStorage(url: destination)
        let originalTracks = try await sourceMovie.load(.tracks)
        let destinationTracks = movie.addMutableTracksCopyingSettings(from: originalTracks)
        guard destinationTracks.count == originalTracks.count else {
            throw JoinError.chapterWrite("Unable to duplicate source tracks")
        }
        // Copy both audio and video sample data; do not leave references to the intermediate file.
        for (original, copy) in zip(originalTracks, destinationTracks) {
            let trackRange = try await original.load(.timeRange)
            try copy.insertTimeRange(trackRange, of: original, at: .zero, copySampleData: true)
        }
        guard let movieVideo = destinationTracks.first(where: { $0.mediaType == .video }),
              let textTrack = movie.addMutableTrack(withMediaType: .text, copySettingsFrom: nil) else {
            throw JoinError.chapterWrite("Unable to create chapter text track")
        }
        let format = try chapterFormat()
        for chapter in chapters {
            try appendChapter(chapter.name, at: chapter.start, duration: chapter.duration,
                              format: format, track: textTrack)
        }
        movieVideo.addTrackAssociation(to: textTrack, type: .chapterList)
        textTrack.isEnabled = false
        try movie.writeHeader(to: destination, fileType: .mov, options: .addMovieHeaderToDestination)
    }

    private static func chapterFormat() throws -> CMFormatDescription {
        // 60-byte QuickTime 'text' sample entry. Other fields are defaults.
        var description = [UInt8](repeating: 0, count: 60)
        description[3] = 60
        description[4...7] = [0x74, 0x65, 0x78, 0x74] // 'text'
        var result: CMTextFormatDescription?
        let status = description.withUnsafeBytes { bytes in
            CMTextFormatDescriptionCreateFromBigEndianTextDescriptionData(
                allocator: kCFAllocatorDefault, bigEndianTextDescriptionData: bytes.baseAddress!,
                size: description.count, flavor: nil, mediaType: kCMMediaType_Text,
                formatDescriptionOut: &result)
        }
        guard status == noErr, let result else {
            throw JoinError.chapterWrite("Could not create a QuickTime text format (\(status))")
        }
        return result
    }

    private static func appendChapter(_ title: String, at start: CMTime, duration: CMTime,
                                      format: CMFormatDescription, track: AVMutableMovieTrack) throws {
        let bytes = Array(title.utf8)
        guard bytes.count < 65_536 else { throw JoinError.chapterWrite("Chapter title too long") }
        // QuickTime text sample: big-endian UInt16 string length followed by text bytes.
        let data = Data([UInt8(bytes.count >> 8), UInt8(bytes.count & 0xff)] + bytes)
        var block: CMBlockBuffer?
        let createStatus = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: data.count,
            blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0,
            dataLength: data.count, flags: 0, blockBufferOut: &block)
        guard createStatus == noErr, let block else {
            throw JoinError.chapterWrite("Could not allocate text sample")
        }
        let copyStatus = data.withUnsafeBytes { bytes in
            CMBlockBufferReplaceDataBytes(with: bytes.baseAddress!, blockBuffer: block,
                                          offsetIntoDestination: 0, dataLength: data.count)
        }
        guard copyStatus == noErr else { throw JoinError.chapterWrite("Could not write text sample") }
        var timing = CMSampleTimingInfo(duration: duration, presentationTimeStamp: start,
                                        decodeTimeStamp: .invalid)
        var sampleLength = data.count
        var sample: CMSampleBuffer?
        let sampleStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault, dataBuffer: block, formatDescription: format,
            sampleCount: 1, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
            sampleSizeEntryCount: 1, sampleSizeArray: &sampleLength, sampleBufferOut: &sample)
        guard sampleStatus == noErr, let sample else {
            throw JoinError.chapterWrite("Could not finalize chapter sample")
        }
        try track.append(sample, decodeTime: nil, presentationTime: nil)
    }
}
