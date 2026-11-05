#if !os(watchOS) && !os(tvOS) && (canImport(UIKit) || canImport(AppKit))
import Foundation
import CoreGraphics
import ImageIO
import Testing
import UniformTypeIdentifiers
import SBJFileResources
@testable import SBJImaging

@Suite("Image document cross-platform")
struct ImageDocumentCrossPlatformTests {
    private func makePNG(width: Int = 64, height: Int = 40) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try #require(CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test func persistsAndRegeneratesCaches() throws {
        let original = try makePNG()
        let source = SBJResourceContent(data: original, contentType: .png)
        let document = SBJImageDocument(source: source, renderCache: .all)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("sample.sbjimage", isDirectory: true)
        try document.write(to: url)
        let reopened = try SBJImageDocument(fileURL: url)
        #expect(reopened.editorInput.source == source)
        #expect(SBJImageDocument.thumbnailImage(at: url, renderIfNeeded: false) != nil)
        #expect(SBJImageDocument.renderedImage(at: url, renderIfNeeded: false) != nil)
    }

    @Test func preservesUnknownMarkupWithoutReinterpretingIt() throws {
        let original = try makePNG()
        let source = SBJResourceContent(data: original, contentType: .png)
        let markup = PhotoMarkup(
            data: Data([0x11, 0x22, 0x33]),
            contentTypeIdentifier: "example.unrecognized-markup",
            canvasSize: PhotoMarkupCanvasSize(CGSize(width: 64, height: 40))
        )
        let document = SBJImageDocument(source: source, renderCache: [])
        var edits = document.editorInput.edits
        edits.markup = markup
        let modified = document.applying(edits)
        let reopened = try SBJImageDocument(serializedRepresentation: modified.serializedRepresentation)
        #expect(reopened.editorInput.edits.markup == markup)
    }

    @Test func regeneratesMissingCachesWithoutChangingSource() throws {
        let original = try makePNG()
        let source = SBJResourceContent(data: original, contentType: .png)
        let document = SBJImageDocument(source: source, renderCache: [])
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("uncached.sbjimage", isDirectory: true)
        try document.write(to: url)
        #expect(SBJImageDocument.thumbnailImage(at: url, renderIfNeeded: false) == nil)
        #expect(SBJImageDocument.renderedImage(at: url, renderIfNeeded: false) == nil)
        #expect(SBJImageDocument.thumbnailImage(at: url, renderIfNeeded: true) != nil)
        #expect(SBJImageDocument.renderedImage(at: url, renderIfNeeded: true) != nil)
        #expect(try SBJImageDocument(fileURL: url).editorInput.source == source)
    }
}
#endif
