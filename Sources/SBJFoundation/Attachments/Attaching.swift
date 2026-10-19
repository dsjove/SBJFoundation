import Foundation
import SBJDataDefinition
import SBJFileResources
import SBJLocalization

/// A named item presented by the standard attachment editor.
///
/// Storage is deliberately not part of this protocol. An attachment may be an
/// embedded document resource, a bookmarked external file, or another app-owned
/// representation.
public protocol Attaching:
    Identifiable,
    Predicated,
    CustomDebugStringConvertible {

    var name: String { get set }
    var displayName: String { get }

    static func propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo?
}

public extension Attaching {
    static func propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
        switch keyPath as AnyKeyPath {
        case \Self.name:
            return SBJPropertyInfo(
                title: "Attachment Name",
                summary: "The user-visible filename of the attachment.",
                details: "Renaming preserves the filename extension.",
                accessibilityLabel: "Attachment name",
                accessibilityHint: "Edits the attachment filename without changing its extension."
            )
        default:
            return nil
        }
    }

    var displayName: String { name }

    func predicated(search: String) -> Bool {
        guard let query = search.querify else { return true }
        return name.predicated(search: query)
    }

    var debugDescription: String {
        "\(Self.self): \(name)"
    }
}

/// An attachment backed by a persistent bookmark to an external file.
///
/// `Attaching` itself remains storage-neutral so embedded attachments can use
/// the same editor without manufacturing bookmark data.
public protocol BookmarkAttaching: AnyObject, Attaching {
    var bookmark: Data { get set }

    init(name: String, bookmark: Data)
}

public extension BookmarkAttaching {
    init(url: URL) throws {
        let bookmark = try url.bookmarkData(
            options: Self.bookmarkCreationOptions,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        self.init(name: url.lastPathComponent, bookmark: bookmark)
    }

    func url() throws -> URL {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: Self.bookmarkResolutionOptions,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale,
           let refreshedBookmark = try? url.bookmarkData(
                options: Self.bookmarkCreationOptions,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
           ) {
            bookmark = refreshedBookmark
        }

        return url
    }
    private static var bookmarkCreationOptions: URL.BookmarkCreationOptions {
#if os(macOS) && !targetEnvironment(macCatalyst)
        // Native sandboxed macOS bookmarks must retain security-scope access.
        [.withSecurityScope]
#else
        // Native iOS/iPadOS, Mac Catalyst, and Designed-for-iPad-on-Mac all
        // use the iOS bookmark model.
        []
#endif
    }

    private static var bookmarkResolutionOptions: URL.BookmarkResolutionOptions {
#if os(macOS) && !targetEnvironment(macCatalyst)
        [.withSecurityScope]
#else
        []
#endif
    }

}

/// Adapts an owning model to the standard attachment editor.
///
/// Apps with staged editor state may instead use `AttachmentsView`'s binding
/// initializer directly.
public protocol AttachmentOwner: AnyObject {
    associatedtype Attachment: Attaching

    var __attachments: [Attachment]? { get set }
    func __createAttachment(_ url: URL) throws -> Attachment
    func __attachmentURL(_ attachment: Attachment) throws -> URL
    func __removeAttachment(_ attachment: Attachment)
}

public extension AttachmentOwner {
    func __removeAttachment(_ attachment: Attachment) {}
}

public extension AttachmentOwner where Attachment: BookmarkAttaching {
    func __attachmentURL(_ attachment: Attachment) throws -> URL {
        try attachment.url()
    }
}

public extension AttachmentOwner {
    var attachmentCount: Int {
        __attachments?.count ?? 0
    }

    func hasAttachment(_ attachment: Attachment) -> Bool {
        __attachments?.contains { $0.id == attachment.id } ?? false
    }

    @discardableResult
    func addAttachment(url: URL) throws -> Attachment {
        var attachment = try __createAttachment(url)
        attachment.name = attachment.name.uniqueFilename(
            existingNames: (__attachments ?? []).map(\.name)
        )

        if __attachments == nil {
            __attachments = []
        }
        __attachments?.append(attachment)
        return attachment
    }

    var sortedAttachments: [Attachment] {
        (__attachments ?? []).enumerated()
            .sorted { lhs, rhs in
                let comparison = lhs.element.displayName.localizedCaseInsensitiveCompare(rhs.element.displayName)
                return comparison == .orderedSame
                    ? lhs.offset < rhs.offset
                    : comparison == .orderedAscending
            }
            .map(\.element)
    }

    func removeAttachment(_ attachment: Attachment) {
        __attachments?.removeAll { $0.id == attachment.id }
    }
}
