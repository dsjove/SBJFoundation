import Foundation

/// Generic discovery and deletion for an app-controlled directory of file packages.
///
/// Active package writes belong to `PackageSession`; this type intentionally has
/// no save API so there is a single owner for the lifecycle of an open package.
public struct PackageCatalogIssue: Identifiable, Equatable, Sendable {
	public let packageURL: URL
	public let errorDescription: String

	public var id: URL { packageURL }
	public var packageName: String { packageURL.lastPathComponent }

	init(packageURL: URL, error: Error) {
		self.packageURL = packageURL
		self.errorDescription = error.localizedDescription
	}

	init(packageURL: URL, errorDescription: String) {
		self.packageURL = packageURL
		self.errorDescription = errorDescription
	}
}

struct PackageCatalogScan<State: Sendable>: Sendable {
	let states: [State]
	/// Package names that physically/metadata-exist in the storage universe.
	let presentPackageNames: Set<String>
	/// Names that must be treated as occupied for identity allocation. This includes
	/// actual package names plus the canonical names implied by decodable packages
	/// whose filename does not match their embedded document ID.
	let occupiedPackageNames: Set<String>
	let unavailablePackageURLs: Set<URL>
	let issues: [PackageCatalogIssue]
}

struct PackageLibraryStore<ID: Hashable & Comparable & Sendable, State: Sendable>: @unchecked Sendable {
	let directory: URL
	let trashDirectory: URL
	let packageURL: @Sendable (ID) -> URL
	let identifier: @Sendable (State) -> ID
	let loadPackage: @Sendable (URL) throws -> State
	let loadCatalogPackage: @Sendable (URL) throws -> State
	let fileAccess: CoordinatedFileAccess
	let fileManager: FileManager
	let isPackageCandidate: @Sendable (URL) -> Bool

	init(
		directory: URL,
		trashDirectory: URL,
		packageURL: @escaping @Sendable (ID) -> URL,
		identifier: @escaping @Sendable (State) -> ID,
		loadPackage: @escaping @Sendable (URL) throws -> State,
		loadCatalogPackage: (@Sendable (URL) throws -> State)? = nil,
		isPackageCandidate: @escaping @Sendable (URL) -> Bool = { _ in true },
		fileManager: FileManager = .default
	) {
		self.directory = directory
		self.trashDirectory = trashDirectory
		self.packageURL = packageURL
		self.identifier = identifier
		self.loadPackage = loadPackage
		self.loadCatalogPackage = loadCatalogPackage ?? loadPackage
		self.fileAccess = CoordinatedFileAccess(fileManager: fileManager)
		self.fileManager = fileManager
		self.isPackageCandidate = isPackageCandidate
	}

	func scanCatalog(excludingIDs: Set<ID> = []) throws -> PackageCatalogScan<State> {
		try prepareDirectory()
		let excludedNames = Set(excludingIDs.map { packageURL($0).lastPathComponent })
		let entries = try fileAccess.read(at: directory) { directoryURL in
			try fileManager.contentsOfDirectory(
				at: directoryURL,
				includingPropertiesForKeys: [.isDirectoryKey],
				options: [.skipsHiddenFiles]
			)
		}

		var states: [State] = []
		var presentPackageNames: Set<String> = []
		var occupiedPackageNames: Set<String> = []
		var issues: [PackageCatalogIssue] = []
		for candidateURL in entries {
			guard isPackageCandidate(candidateURL) else { continue }
			presentPackageNames.insert(candidateURL.lastPathComponent)
			occupiedPackageNames.insert(candidateURL.lastPathComponent)
			guard !excludedNames.contains(candidateURL.lastPathComponent) else { continue }
			do {
				guard try candidateURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
					issues.append(.init(
						packageURL: candidateURL,
						errorDescription: "Expected a document package directory, but this item is not a directory."
					))
					continue
				}
				let state = try fileAccess.read(at: candidateURL, { try loadCatalogPackage($0) })
				let id = identifier(state)
				occupiedPackageNames.insert(packageURL(id).lastPathComponent)
				guard candidateURL.lastPathComponent == packageURL(id).lastPathComponent else {
					issues.append(.init(packageURL: candidateURL, errorDescription: "The package filename does not match the document ID stored inside it."))
					continue
				}
				states.append(state)
			} catch {
				issues.append(.init(packageURL: candidateURL, error: error))
			}
		}
		return .init(
			states: states.sorted { identifier($0) < identifier($1) },
			presentPackageNames: presentPackageNames,
			occupiedPackageNames: occupiedPackageNames,
			unavailablePackageURLs: [],
			issues: issues.sorted { $0.packageName < $1.packageName }
		)
	}

	/// Scans the package URLs supplied by iCloud metadata. The metadata result is
	/// authoritative for existence, even when a package is not downloaded yet.
	/// Unreadable ubiquitous packages are requested for download and remain in
	/// `presentPackageNames` so they cannot be mistaken for deletions.
	func scanCatalog(
		packageURLs: Set<URL>,
		excludingIDs: Set<ID> = []
	) -> PackageCatalogScan<State> {
		let excludedNames = Set(excludingIDs.map { packageURL($0).lastPathComponent })
		var states: [State] = []
		var presentPackageNames: Set<String> = []
		var occupiedPackageNames: Set<String> = []
		var unavailablePackageURLs: Set<URL> = []
		var issues: [PackageCatalogIssue] = []

		for candidateURL in packageURLs {
			guard isPackageCandidate(candidateURL) else { continue }
			presentPackageNames.insert(candidateURL.lastPathComponent)
			occupiedPackageNames.insert(candidateURL.lastPathComponent)
			guard !excludedNames.contains(candidateURL.lastPathComponent) else { continue }
			do {
				let state = try fileAccess.read(at: candidateURL) { try loadCatalogPackage($0) }
				let id = identifier(state)
				occupiedPackageNames.insert(packageURL(id).lastPathComponent)
				guard candidateURL.lastPathComponent == packageURL(id).lastPathComponent else {
					issues.append(.init(packageURL: candidateURL, errorDescription: "The package filename does not match the document ID stored inside it."))
					continue
				}
				states.append(state)
			} catch {
				unavailablePackageURLs.insert(candidateURL)
				issues.append(.init(packageURL: candidateURL, error: error))
				if fileManager.isUbiquitousItem(at: candidateURL) {
					try? fileManager.startDownloadingUbiquitousItem(at: candidateURL)
				}
			}
		}

		return .init(
			states: states.sorted { identifier($0) < identifier($1) },
			presentPackageNames: presentPackageNames,
			occupiedPackageNames: occupiedPackageNames,
			unavailablePackageURLs: unavailablePackageURLs,
			issues: issues.sorted { $0.packageName < $1.packageName }
		)
	}

	func loadCatalogPackage(at candidateURL: URL) throws -> State? {
		var isDirectory: ObjCBool = false
		guard fileManager.fileExists(atPath: candidateURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
			return nil
		}
		let state = try fileAccess.read(at: candidateURL) { try loadCatalogPackage($0) }
		let id = identifier(state)
		guard candidateURL.lastPathComponent == packageURL(id).lastPathComponent else {
			throw CocoaError(.fileReadCorruptFile)
		}
		return state
	}

	/// Loads a package supplied by a document picker or other external provider,
	/// holding security-scoped access for the complete coordinated read.
	func loadExternalPackage(from url: URL) throws -> State {
		try fileAccess.readSecurityScoped(at: url) { try loadPackage($0) }
	}

	/// Atomically removes a package from live discovery by moving the complete
	/// package into the library's private trash directory. Physical deletion is
	/// intentionally separate so catalog scans never observe a half-deleted package.
	func moveToTrash(id: ID) throws {
		try prepareDirectory()
		try prepareTrashDirectory()
		let sourceURL = packageURL(id)
		guard fileManager.fileExists(atPath: sourceURL.path) else { return }

		let destinationURL = trashDirectory.appendingPathComponent(
			"\(sourceURL.lastPathComponent).\(UUID().uuidString)",
			isDirectory: true
		)
		try fileAccess.moveItem(at: sourceURL, to: destinationURL)
	}

	/// Best-effort housekeeping entry point for packages or other rogue files left
	/// in trash by an interrupted cleanup. The caller decides whether failures are
	/// user-visible; normal app-launch cleanup deliberately ignores them.
	func emptyTrash() throws {
		try prepareTrashDirectory()
		let entries = try fileManager.contentsOfDirectory(
			at: trashDirectory,
			includingPropertiesForKeys: nil,
			options: []
		)
		for entry in entries {
			try fileAccess.removeItem(at: entry)
		}
	}

	private func prepareDirectory() throws {
		try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
	}

	private func prepareTrashDirectory() throws {
		try fileManager.createDirectory(at: trashDirectory, withIntermediateDirectories: true)
	}
}
