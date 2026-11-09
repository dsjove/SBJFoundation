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
        #expect(defaults.setPoster)
        #expect(defaults.colorEdits)
        #expect(defaults.posterEdits)

        let casting = MovieViewerOptions(setPoster: true, colorEdits: true, posterEdits: false)
        #expect(casting.setPoster)
        #expect(casting.colorEdits)
        #expect(!casting.posterEdits)

        let movie = MovieViewerOptions(setPoster: true, colorEdits: true, posterEdits: true)
        #expect(movie.posterEdits)
    }

    @Test @MainActor func handlerCanDeclineEmbedding() async throws {
        let handler: MoviePosterHandler = { time, image in
            #expect(time == 1.5)
            #expect(image?.width == 1)
            return false
        }
        let space = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: nil, width: 1, height: 1,
                                bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let image = context.makeImage()!
        #expect(try await handler(1.5, image) == false)
    }

    @Test @MainActor func handlerReceivesNilForClear() async throws {
        var cleared = false
        let handler: MoviePosterHandler = { time, image in
            #expect(time == nil)
            #expect(image == nil)
            cleared = true
            return false
        }
        #expect(try await handler(nil, nil) == false)
        #expect(cleared)
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
