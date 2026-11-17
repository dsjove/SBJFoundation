#if os(macOS) || os(iOS) || os(visionOS)
import Foundation
import CoreGraphics
import Testing
import SBJFileResources
@testable import SBJImaging

@Suite("Movie viewer poster API")
struct MovieViewerPosterAPITests {
    @Test func defaultOptionsAndConfigurations() {
        let defaults = MovieViewerOptions()
        #expect(defaults.allowsFrameSelection)
        #expect(!defaults.allowsEmbeddedPosterEditing)
        #expect(defaults.allowsColorAdjustments)
        #expect(defaults.allowsImageTools)

        let combined = MovieViewerOptions(allowsFrameSelection: true,
            allowsEmbeddedPosterEditing: true, allowsColorAdjustments: true,
            allowsImageTools: true)
        #expect(combined.allowsFrameSelection)
        #expect(combined.allowsEmbeddedPosterEditing)

        let playbackOnly = MovieViewerOptions(allowsFrameSelection: false,
            allowsEmbeddedPosterEditing: false)
        #expect(!playbackOnly.allowsFrameSelection)
        #expect(!playbackOnly.allowsEmbeddedPosterEditing)
    }

    @Test @MainActor func handlerCanDeclineEmbedding() async throws {
        let handler: MoviePosterHandler = { action in
            guard case .selectFrame(let time, let image) = action else {
                Issue.record("Expected a frame selection")
                return false
            }
            #expect(time == 1.5)
            #expect(image.width == 1)
            return false
        }
        let space = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: nil, width: 1, height: 1,
                                bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let image = context.makeImage()!
        #expect(try await handler(.selectFrame(time: 1.5, image: image)) == false)
    }

    @Test @MainActor func clearOperationsAreDistinct() async throws {
        var clearedFrame = false
        var clearedArtwork = false
        let handler: MoviePosterHandler = { action in
            switch action {
            case .clearFrame: clearedFrame = true
            case .clearArtwork: clearedArtwork = true
            default: Issue.record("Unexpected poster action")
            }
            return false
        }
        #expect(try await handler(.clearFrame) == false)
        #expect(clearedFrame && !clearedArtwork)
        #expect(try await handler(.clearArtwork) == false)
        #expect(clearedArtwork)
    }

    @Test @MainActor func existingEditRecipeCanInitializeEditor() {
        let photo = SBJResourceContent(data: Data(), contentType: .png)
        let geometry = PhotoEditGeometry(
            crop: .init(option: .none, sourceSize: CGSize(width: 100, height: 100))
        )
        let edits = PhotoEditResult(geometry: geometry, color: .init())
        // API-level compilation test for injection of an existing edit recipe.
        _ = PhotoEditor(resource: photo, edits: edits,
                        allowsUnchangedCompletion: true) { (_: PhotoEditResult?) in }
    }
}
#endif
