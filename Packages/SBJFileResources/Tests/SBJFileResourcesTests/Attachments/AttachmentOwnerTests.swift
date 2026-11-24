import Foundation
import Testing
@testable import SBJFileResources

private struct TestAttachment: Attaching {
    let id: UUID
    var name: String
}

private final class TestAttachmentOwner: AttachmentOwner {
    var __attachments: [TestAttachment]?

    func __createAttachment(_ url: URL) throws -> TestAttachment {
        TestAttachment(id: UUID(), name: url.lastPathComponent)
    }

    func __attachmentURL(_ attachment: TestAttachment) throws -> URL {
        URL(fileURLWithPath: attachment.name)
    }
}

@Suite("Attachment ownership")
struct AttachmentOwnerTests {
    @Test func resolvesCaseInsensitiveNameCollisionsAndRemovesByIdentity() throws {
        let owner = TestAttachmentOwner()
        let first = try owner.addAttachment(url: URL(fileURLWithPath: "/tmp/photo.jpg"))
        let second = try owner.addAttachment(url: URL(fileURLWithPath: "/tmp/Photo.JPG"))
        #expect(owner.attachmentCount == 2)
        #expect(first.name == "photo.jpg")
        #expect(second.name == "Photo 2.JPG")
        #expect(owner.hasAttachment(second))
        owner.removeAttachment(first)
        #expect(owner.attachmentCount == 1)
        #expect(!owner.hasAttachment(first))
    }

    @Test func stableSortUsesDisplayNameAndInsertionOrderForTies() throws {
        let owner = TestAttachmentOwner()
        let first = try owner.addAttachment(url: URL(fileURLWithPath: "/tmp/z.txt"))
        let second = try owner.addAttachment(url: URL(fileURLWithPath: "/tmp/A.txt"))
        #expect(owner.sortedAttachments.map(\.id) == [second.id, first.id])
    }
}
