#if !os(watchOS)
import Foundation

public enum DocumentRole: Int, SBJFoundationType, Comparable, Sendable {
	case user
	case builtIn
	case debug

	public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// URL identity contract for documents that support app/deep-link URLs.
public protocol DocumentURLRouting {
	associatedtype DocumentID: Hashable & Comparable & Sendable

	static func documentID(from url: URL) -> DocumentID?
	static func url(forDocumentID id: DocumentID) -> URL?
}

public extension DocumentURLRouting {
	static func documentID(from url: URL) -> DocumentID? { nil }
	static func url(forDocumentID id: DocumentID) -> URL? { nil }
}

/// Immutable package state used by a `PackageDocument`.
public protocol PackageDocumentSnapshot: Sendable, Equatable {
	associatedtype ID: Hashable & Comparable & Sendable
	var id: ID { get }
}

/// Domain contract for a live document managed by `PackageDocumentLibrary`.
///
/// The conforming document owns model semantics and package-format policy.
/// The library owns discovery, canonical identity, sessions, saving, imports,
/// external-change handling, URL opening, package export, and platform differences.

public struct PackageDocumentNotice: Identifiable, Sendable, Equatable {
	public enum Kind: Sendable, Equatable {
		case persistenceFailure
		case resourceWarning
		case identityRepair
		case storageChange
		case catalogIssue
	}

	public let id: UUID
	public let kind: Kind
	public let title: String
	public let message: String

	public init(id: UUID = UUID(), kind: Kind, title: String, message: String) {
		self.id = id
		self.kind = kind
		self.title = title
		self.message = message
	}
}

public struct PackageDocumentWriteWarning: LocalizedError, Sendable, Equatable {
	public let message: String

	public init(_ message: String) { self.message = message }
	public var errorDescription: String? { message }
}

public struct PackageDocumentWriteResult {
	public let wrapper: FileWrapper
	public let warnings: [PackageDocumentWriteWarning]

	public init(wrapper: FileWrapper, warnings: [PackageDocumentWriteWarning] = []) {
		self.wrapper = wrapper
		self.warnings = warnings
	}
}

public protocol PackageDocument: AnyObject, Comparable, SendableMetatype, DocumentURLRouting
where DocumentID == Snapshot.ID {
	associatedtype Snapshot: PackageDocumentSnapshot

	var id: Snapshot.ID { get }
	var name: String { get }
	var role: DocumentRole { get }
	var snapshot: Snapshot { get }
	var modifiedAt: Date { get }

	init(restoring snapshot: Snapshot)
	func restore(from snapshot: Snapshot)
	/// Refreshes only the catalog-visible portion of an existing live document.
	/// The default implementation restores the complete snapshot; document types
	/// that use lightweight catalog snapshots can override this to preserve
	/// resources that are intentionally omitted from catalog discovery.
	func restoreCatalog(from snapshot: Snapshot)
	func markModified(at date: Date)

	static func makeNewDocument() -> Self
	static func makeDuplicate(of source: Self, named name: String) -> Self
	static func makeDocumentID() -> Snapshot.ID
	static func isValidUserDocumentID(_ id: Snapshot.ID) -> Bool
	static func replacingID(in snapshot: Snapshot, with id: Snapshot.ID) -> Snapshot

	static func storageLocation(fileManager: FileManager) -> PackageStorageLocation<Snapshot.ID>
	static func validateImportURL(_ url: URL) throws
	static func prepareImport(_ snapshot: Snapshot) -> Snapshot
	static func finalizedImport(_ snapshot: Snapshot, asCopy: Bool) -> Snapshot
	static func snapshotForExport(_ snapshot: Snapshot) -> Snapshot
	static func isSnapshotWritable(_ snapshot: Snapshot) -> Bool

	/// Complete package representation used for export and detached copies.
	static func fileWrapper(for snapshot: Snapshot) throws -> FileWrapper
	static func writeResult(for snapshot: Snapshot) throws -> PackageDocumentWriteResult
	/// Persists an active document at its coordinated package URL. The default
	/// implementation replaces the complete package. Document formats with
	/// secondary resources may override this to update primary data independently
	/// and leave unchanged resources physically untouched.
	static func persist(_ snapshot: Snapshot, to url: URL) throws -> [PackageDocumentWriteWarning]
	static func snapshot(from wrapper: FileWrapper) throws -> Snapshot
	/// Opens a persisted package when its URL is available. Document types may
	/// use the URL as lazy backing storage instead of materializing package resources.
	static func snapshot(from wrapper: FileWrapper, at url: URL) throws -> Snapshot
	/// Lightweight snapshot used for library discovery. URL-based access lets
	/// document types read only the files needed for catalog UI without first
	/// materializing the package tree as a `FileWrapper`.
	static func catalogSnapshot(at url: URL) throws -> Snapshot
}

public extension PackageDocument {
	var role: DocumentRole { .user }

	internal func markModified() { markModified(at: .now) }

	func restoreCatalog(from snapshot: Snapshot) { restore(from: snapshot) }

	static func snapshotForExport(_ snapshot: Snapshot) -> Snapshot { snapshot }
	static func isSnapshotWritable(_ snapshot: Snapshot) -> Bool { true }
	static func writeResult(for snapshot: Snapshot) throws -> PackageDocumentWriteResult {
		.init(wrapper: try fileWrapper(for: snapshot))
	}
	static func persist(_ snapshot: Snapshot, to url: URL) throws -> [PackageDocumentWriteWarning] {
		let result = try writeResult(for: snapshot)
		try FileManager.default.createDirectory(
			at: url.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		try result.wrapper.write(
			to: url,
			options: .atomic,
			originalContentsURL: FileManager.default.fileExists(atPath: url.path) ? url : nil
		)
		return result.warnings
	}
	static func snapshot(from wrapper: FileWrapper, at url: URL) throws -> Snapshot {
		try snapshot(from: wrapper)
	}
	static func catalogSnapshot(at url: URL) throws -> Snapshot {
		try snapshot(from: FileWrapper(url: url, options: .immediate))
	}
}
#endif
