#if os(macOS) || os(iOS) || os(visionOS)
import AVFoundation
import XCTest
@testable import SBJImaging

final class PosterArtworkMetadataTests: XCTestCase {
    private func item(identifier: AVMetadataIdentifier, value: String = "value") -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as NSString
        return item
    }

    func testArtworkIdentifierIsRemovedButOtherMetadataSurvives() {
        let poster = item(identifier: .quickTimeMetadataArtwork)
        let title = item(identifier: .quickTimeMetadataTitle, value: "Example title")
        let snapshot = PosterMetadataSnapshot(
            items: [title, poster], commonItems: [poster], byFormat: []
        )
        XCTAssertTrue(snapshot.containsArtwork)
        let filtered = filteredPosterMetadata(snapshot)
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.identifier, .quickTimeMetadataTitle)
    }

    func testFormatSpecificArtworkIsFoundEvenWhenTopLevelMetadataIsEmpty() {
        let poster = item(identifier: .quickTimeMetadataArtwork)
        let snapshot = PosterMetadataSnapshot(
            items: [], commonItems: [],
            byFormat: [(format: .quickTimeMetadata, items: [poster])]
        )
        XCTAssertTrue(snapshot.containsArtwork)
        XCTAssertTrue(filteredPosterMetadata(snapshot).isEmpty)
    }

    func testFormatSpecificNonArtworkMetadataIsPreserved() {
        let title = item(identifier: .quickTimeMetadataTitle, value: "Title")
        let snapshot = PosterMetadataSnapshot(
            items: [], commonItems: [],
            byFormat: [(format: .quickTimeMetadata, items: [title])]
        )
        XCTAssertFalse(snapshot.containsArtwork)
        XCTAssertEqual(filteredPosterMetadata(snapshot).count, 1)
    }

    func testOverlappingTopLevelAndFormatMetadataIsNotDuplicated() {
        let title = item(identifier: .quickTimeMetadataTitle)
        let snapshot = PosterMetadataSnapshot(
            items: [title], commonItems: [],
            byFormat: [(format: .quickTimeMetadata, items: [title])]
        )
        XCTAssertEqual(filteredPosterMetadata(snapshot).count, 1)
    }

    func testRepeatedMetadataValuesArePreserved() {
        let title1 = item(identifier: .quickTimeMetadataTitle, value: "First")
        let title2 = item(identifier: .quickTimeMetadataTitle, value: "Second")
        let snapshot = PosterMetadataSnapshot(
            items: [title1], commonItems: [],
            byFormat: [(format: .quickTimeMetadata, items: [title1, title2])]
        )
        XCTAssertEqual(filteredPosterMetadata(snapshot).count, 2)
    }
}
#endif
