import Foundation
import UniformTypeIdentifiers

/// A concrete attachment presentation independent of attachment storage.
///
/// URL-backed attachments keep their existing URL. Embedded attachments
/// are materialized to a temporary file because Quick Look, sharing, and
/// OS opening operate on file URLs.
@SBJStructure
public struct URLAttachment: Identifiable, SBJFoundationType, Sendable {
	@SBJUUID(nonzero: true)
	public let id: UUID
	@SBJURL(allowed: [.file])
	public let url: URL
	@SBJString(minLength: 1)
	public let displayName: String

	public init(
		id: UUID = UUID(),
		url: URL,
		displayName: String? = nil
	) {
		self.id = id
		self.url = url
		self.displayName = displayName ?? url.lastPathComponent
	}

	public init(
		id: UUID = UUID(),
		content: SBJResourceContent,
		filename: String,
		displayName: String? = nil
	) throws {
		self.id = id
		self.url = try Self.materialize(content: content, filename: filename)
		self.displayName = displayName ?? filename
	}

	public static func propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
		switch keyPath as AnyKeyPath {
		case \Self.url:
			return SBJPropertyInfo(
				title: "Attachment URL",
				summary: "File URL used to preview or share the attachment.",
				details: "Embedded attachment content may be materialized to a temporary file URL."
			)
		case \Self.displayName:
			return SBJPropertyInfo(
				title: "Attachment Name",
				summary: "Name presented for the attachment.",
				details: "Defaults to the file URL's last path component.",
				accessibilityLabel: "Attachment"
			)
		default:
			return nil
		}
	}

	private static func materialize(content: SBJResourceContent, filename: String) throws -> URL {
		let directory = FileManager.default.temporaryDirectory
			.appendingPathComponent("URLAttachment", isDirectory: true)
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(
			at: directory,
			withIntermediateDirectories: true
		)

		var safeFilename = filename.sanitizedFilename(contentType: content.contentType)
		if safeFilename.isEmpty {
			safeFilename = "Attachment".sanitizedFilename(contentType: content.contentType)
		}
		let url = directory.appendingPathComponent(safeFilename)
		switch content.storageRepresentation {
		case .directory:
			try content.storageFileWrapper().write(to: url, options: .atomic, originalContentsURL: nil)
		case .regularFile:
			try content.data.write(to: url, options: .atomic)
		}
		return url
	}
}
