#if !os(watchOS) && !os(tvOS) && canImport(UIKit)
import Foundation
import CoreLocation
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import SBJFoundation

@Suite("Photo edit behavior")
struct PhotoEditBehaviorTests {
    @Test func originalCropCanTransposeDimensions() {
        let option = PhotoCropOption.original
        let source = CGSize(width: 400, height: 300)

        #expect(abs(option.aspectRatio(
            sourceSize: source,
            freeAspectRatio: 1,
            swappingDimensions: false
        ) - (4.0 / 3.0)) < 0.000_001)

        #expect(abs(option.aspectRatio(
            sourceSize: source,
            freeAspectRatio: 1,
            swappingDimensions: true
        ) - (3.0 / 4.0)) < 0.000_001)
    }

    @Test func ratioCropCanTransposeDimensions() {
        let option = PhotoCropOption.ratio(width: 4, height: 3)
        let source = CGSize(width: 400, height: 300)

		#expect(abs(option.aspectRatio(
			sourceSize: source,
			freeAspectRatio: 1,
			swappingDimensions: false
		) - (4.0 / 3.0)) < 0.000_001)

		#expect(abs(option.aspectRatio(
			sourceSize: source,
			freeAspectRatio: 1,
			swappingDimensions: true
		) - (3.0 / 4.0)) < 0.000_001)
    }


    @Test func cropOptionsNormalizeInitialCrop() {
        #expect(PhotoEditorOptions(
            cropOptions: [],
            initialCrop: .square
        ).effectiveInitialCrop == .none)

        #expect(PhotoEditorOptions(
            cropOptions: [.square],
            initialCrop: .none
        ).effectiveInitialCrop == .square)

        #expect(PhotoEditorOptions(
            cropOptions: [.none, .square],
            initialCrop: .square
        ).effectiveInitialCrop == .square)

        #expect(PhotoEditorOptions(
            cropOptions: [.square, .fourThree],
            initialCrop: .free
        ).effectiveInitialCrop == .square)
    }

    @Test func cropToolbarPolicyReflectsConfiguredOptions() {
        #expect(!PhotoEditorOptions(cropOptions: []).showsCropChoices)
        #expect(!PhotoEditorOptions(cropOptions: [.square]).showsCropChoices)
        #expect(PhotoEditorOptions(cropOptions: [.none, .square]).showsCropChoices)

        #expect(!PhotoEditorOptions(cropOptions: []).allowsCropDimensionSwap)
        #expect(!PhotoEditorOptions(cropOptions: [.none]).allowsCropDimensionSwap)
        #expect(!PhotoEditorOptions(cropOptions: [.square]).allowsCropDimensionSwap)
        #expect(!PhotoEditorOptions(cropOptions: [.none, .square]).allowsCropDimensionSwap)
        #expect(!PhotoEditorOptions(cropOptions: [.free]).allowsCropDimensionSwap)
        #expect(PhotoEditorOptions(cropOptions: [.original]).allowsCropDimensionSwap)
        #expect(PhotoEditorOptions(cropOptions: [.fourThree]).allowsCropDimensionSwap)
    }

    @Test func photoEditorOptionsRoundTripThroughCodable() throws {
        let original = PhotoEditorOptions(
            cropOptions: [.none, .square, .ratio(width: 5, height: 7)],
            initialCrop: .square,
            allowsQuarterTurnRotation: false,
            allowsFreeRotation: true,
            allowsMirror: false,
            framingConstraint: .cover,
            allowsNoneFraming: false,
            maximumMagnification: 5,
            renderCropGhost: -1,
            allowsMarkup: false,
            allowsShare: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PhotoEditorOptions.self, from: data)
        #expect(decoded == original)
    }

    @Test func olderCropStateWithoutSwapFlagDecodesUnswapped() throws {
        let current = PhotoCropState(
            option: .ratio(width: 4, height: 3),
            sourceSize: CGSize(width: 400, height: 300),
            swapsDimensions: true
        )
        let encoded = try JSONEncoder().encode(current)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "swapsDimensions")
        let oldData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(PhotoCropState.self, from: oldData)
        #expect(decoded.swapsDimensions == false)
    }
    @Test func olderGeometryDecodesIdentityReservedTransforms() throws {
        let geometry = PhotoEditGeometry(crop: .init(option: .none, sourceSize: CGSize(width: 400, height: 300)))
        let encoded = try JSONEncoder().encode(geometry)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "perspective")
        object.removeValue(forKey: "skew")
        let oldData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(PhotoEditGeometry.self, from: oldData)
        #expect(decoded.perspective == .identity)
        #expect(decoded.skew == .identity)
    }

    @Test func imageDocumentPackageRoundTripsPortableState() throws {
        let source = SBJResourceContent(data: Data([1, 2, 3]), contentType: .png)
        var geometry = PhotoEditGeometry(crop: .init(option: .square, freeAspectRatio: 1))
        geometry.rotation = .init(quarterTurns: 1, fineDegrees: 2.5)
        geometry.skew = .init(horizontalDegrees: 1.25)
        let edits = PhotoEditResult(
            displayName: "Example",
            description: "Example description",
            geometry: geometry
        )
        let document = SBJImageDocument(source: source, renderCache: [])
            .applying(edits)

        let restored = try SBJImageDocument(serializedRepresentation: document.serializedRepresentation)
        #expect(restored.editorInput.source == source)
        #expect(restored.editorInput.edits == edits)
    }

    @Test func imageDocumentLocationRoundTripsAsJSON() throws {
        let source = SBJResourceContent(data: Data([1, 2, 3]), contentType: .png)
        let timestamp = Date(timeIntervalSinceReferenceDate: 812_345_678)
        let location = CLLocation(
            coordinate: .init(latitude: 38.6270, longitude: -90.1994),
            altitude: 142.5,
            horizontalAccuracy: 4.25,
            verticalAccuracy: 6.5,
            course: 123.0,
            courseAccuracy: 2.0,
            speed: 7.5,
            speedAccuracy: 0.75,
            timestamp: timestamp
        )
        let document = SBJImageDocument(
            source: source,
            location: location,
            renderCache: []
        )

        let restored = try SBJImageDocument(serializedRepresentation: document.serializedRepresentation)
        let restoredLocation = try #require(restored.location)

        #expect(restoredLocation.coordinate.latitude == location.coordinate.latitude)
        #expect(restoredLocation.coordinate.longitude == location.coordinate.longitude)
        #expect(restoredLocation.altitude == location.altitude)
        #expect(restoredLocation.horizontalAccuracy == location.horizontalAccuracy)
        #expect(restoredLocation.verticalAccuracy == location.verticalAccuracy)
        #expect(restoredLocation.course == location.course)
        #expect(restoredLocation.courseAccuracy == location.courseAccuracy)
        #expect(restoredLocation.speed == location.speed)
        #expect(restoredLocation.speedAccuracy == location.speedAccuracy)
        #expect(restoredLocation.timestamp == location.timestamp)
    }

    @Test func imageDocumentWithoutLocationRoundTripsAsNil() throws {
        let source = SBJResourceContent(data: Data([1, 2, 3]), contentType: .png)
        let document = SBJImageDocument(source: source, renderCache: [])

        let restored = try SBJImageDocument(serializedRepresentation: document.serializedRepresentation)
        #expect(restored.location == nil)
    }

    @Test func imageDocumentRenderedCacheIncludesLocationGPSMetadata() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 12)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 12))
        }
        let jpeg = try #require(image.jpegData(compressionQuality: 0.95))
        let source = SBJResourceContent(data: jpeg, contentType: .jpeg)
        let location = CLLocation(
            coordinate: .init(latitude: 38.6270, longitude: -90.1994),
            altitude: 142.5,
            horizontalAccuracy: 4.25,
            verticalAccuracy: 6.5,
            timestamp: Date(timeIntervalSinceReferenceDate: 812_345_678)
        )

        // Match the capture/edit flow: the full render exists before GPS is attached.
        var document = SBJImageDocument(source: source, renderCache: .rendered)
        document.location = location

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let packageURL = directory.appendingPathComponent("rendered.sbjimage", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try document.write(to: packageURL)
        let renderedURL = try #require(SBJImageDocument.renderedURL(in: packageURL))
        let renderedData = try Data(contentsOf: renderedURL)
        let renderedLocation = try #require(CLLocation(image: renderedData))

        #expect(abs(renderedLocation.coordinate.latitude - location.coordinate.latitude) < 0.000_001)
        #expect(abs(renderedLocation.coordinate.longitude - location.coordinate.longitude) < 0.000_001)
    }

    @Test func imageDocumentPresentationHonorsRenderIfNeeded() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 20)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 20))
        }
        let source = SBJResourceContent(
            data: try #require(image.pngData()),
            contentType: .png
        )
        let document = SBJImageDocument(source: source, renderCache: [])

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let packageURL = directory.appendingPathComponent("uncached.sbjimage", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try document.write(to: packageURL)

        #expect(SBJImageDocument.thumbnailImage(at: packageURL, renderIfNeeded: false) == nil)
        #expect(SBJImageDocument.renderedImage(at: packageURL, renderIfNeeded: false) == nil)
        #expect(SBJImageDocument.thumbnailImage(at: packageURL, renderIfNeeded: true) != nil)
        #expect(SBJImageDocument.renderedImage(at: packageURL, renderIfNeeded: true) != nil)
    }

    @Test func imageDocumentResourceContentUsesLocalPackageType() throws {
        let source = SBJResourceContent(data: Data([1, 2, 3]), contentType: .png)
        let content = try #require(
            SBJImageDocument(source: source, renderCache: []).resourceContent()
        )

        #expect(content.contentType.conforms(to: .package))
        #expect(content.contentType.preferredFilenameExtension == SBJImageDocument.packageExtension)
        let restored = try SBJImageDocument(resourceContent: content)
        #expect(restored.editorInput.source == source)
    }

    @Test func preservingImageEditsRejectsNonImage() {
        let source = SBJResourceContent(data: Data([1, 2, 3]), contentType: .plainText)
        #expect(source.preservingImageEdits() == nil)
    }

    @Test func cropMutationsOwnTheirDependentGeometryReset() {
        var geometry = PhotoEditGeometry(
            crop: .init(option: .ratio(width: 4, height: 3), freeAspectRatio: 4.0 / 3.0),
            placement: .init(x: 0.2, y: -0.1),
            magnification: 2
        )

        geometry.setCropDimensionsSwapped(true)
        #expect(geometry.crop.swapsDimensions)
        #expect(geometry.placement == .zero)
        #expect(geometry.magnification == 1)

        geometry.placement = .init(x: 0.1, y: 0.1)
        geometry.magnification = 1.5
        geometry.selectCrop(.square)
        #expect(geometry.crop.option == .square)
        #expect(geometry.placement == .zero)
        #expect(geometry.magnification == 1)
    }

    @Test func originalCropSwapCountsAsGeometryEdit() {
        let normal = PhotoEditGeometry(
            crop: .init(option: .original, freeAspectRatio: 4.0 / 3.0)
        )
        var swapped = normal
        swapped.setCropDimensionsSwapped(true)

        #expect(normal.editComparisonValue != swapped.editComparisonValue)
    }

    @Test func freeCropResizeClampsAndResetsDependentGeometry() {
        var geometry = PhotoEditGeometry(
            crop: .init(option: .free, freeAspectRatio: 1),
            placement: .init(x: 0.25, y: 0.25),
            magnification: 2
        )

        geometry.resizeFreeCrop(to: 10)
        #expect(geometry.crop.freeAspectRatio == 4)
        #expect(geometry.placement == .zero)
        #expect(geometry.magnification == 1)
    }

}
#endif
