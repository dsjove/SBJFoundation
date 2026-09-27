#if !os(watchOS)
import Foundation

public enum DocumentRole: Int, Comparable, Sendable, Codable {
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

	static func storageLocation(fileManager: FileManager) -> PackageStorageLocation<Snapshot.ID>
	static func validateImportURL(_ url: URL) throws
	static func prepareImport(_ snapshot: Snapshot) -> Snapshot
	static func finalizedImport(_ snapshot: Snapshot, asCopy: Bool) -> Snapshot
	static func snapshotForExport(_ snapshot: Snapshot) -> Snapshot

	static func fileWrapper(for snapshot: Snapshot) throws -> FileWrapper
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
	static func snapshot(from wrapper: FileWrapper, at url: URL) throws -> Snapshot {
		try snapshot(from: wrapper)
	}
	static func catalogSnapshot(at url: URL) throws -> Snapshot {
		try snapshot(from: FileWrapper(url: url, options: .immediate))
	}
}
#endif
