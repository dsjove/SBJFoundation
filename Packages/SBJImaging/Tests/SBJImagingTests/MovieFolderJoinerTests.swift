import XCTest
import CoreGraphics
@testable import SBJImaging

final class MovieFolderJoinerTests: XCTestCase {
    func testDestinationInsideSelectedFolder() async {
        await MainActor.run {
            let selected = URL(fileURLWithPath: "/Movies/Collection/Part Clips", isDirectory: true)
            XCTAssertEqual(MovieFolderJoiner.destinationURL(for: selected).path,
                           "/Movies/Collection/Part Clips/Part Clips.mov")
        }
    }

    func testCenteredLetterboxEnlargesWithoutDistortion() async {
        await MainActor.run {
            let size = CGSize(width: 640, height: 480)
            let canvas = CGSize(width: 1920, height: 1080)
            let transform = MovieFolderJoiner.aspectFitTransform(
                size: size, preferredTransform: .identity, canvas: canvas)
            let result = CGRect(origin: .zero, size: size).applying(transform)
            XCTAssertEqual(result.width, 1440, accuracy: 0.001)
            XCTAssertEqual(result.height, 1080, accuracy: 0.001)
            XCTAssertEqual(result.midX, 960, accuracy: 0.001)
            XCTAssertEqual(result.midY, 540, accuracy: 0.001)
        }
    }

    func testSourceNeverShrinksOnLargestDimensionsCanvas() async {
        await MainActor.run {
            let canvas = CGSize(width: 1920, height: 1080)
            let source = CGSize(width: 1920, height: 1080)
            let transform = MovieFolderJoiner.aspectFitTransform(
                size: source, preferredTransform: .identity, canvas: canvas)
            let fitted = CGRect(origin: .zero, size: source).applying(transform)
            XCTAssertGreaterThanOrEqual(fitted.width, source.width)
            XCTAssertGreaterThanOrEqual(fitted.height, source.height)
        }
    }

    func testPortraitRotationFitsCanvas() async {
        await MainActor.run {
            let size = CGSize(width: 1920, height: 1080)
            let rotation = CGAffineTransform(rotationAngle: .pi / 2)
            let canvas = CGSize(width: 1920, height: 1920)
            let transform = MovieFolderJoiner.aspectFitTransform(
                size: size, preferredTransform: rotation, canvas: canvas)
            let fitted = CGRect(origin: .zero, size: size).applying(transform).standardized
            XCTAssertEqual(fitted.width, 1080, accuracy: 0.001)
            XCTAssertEqual(fitted.height, 1920, accuracy: 0.001)
            XCTAssertLessThanOrEqual(fitted.width, canvas.width + 0.001)
            XCTAssertLessThanOrEqual(fitted.height, canvas.height + 0.001)
            XCTAssertEqual(fitted.midX, canvas.width / 2, accuracy: 0.001)
            XCTAssertEqual(fitted.midY, canvas.height / 2, accuracy: 0.001)
        }
    }
}
