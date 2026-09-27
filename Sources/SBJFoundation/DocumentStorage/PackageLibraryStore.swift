import Foundation

/// Generic discovery and deletion for an app-controlled directory of file packages.
///
/// Active package writes belong to `PackageSession`; this type intentionally has
/// no save API so there is a single owner for the lifecycle of an open package.
struct PackageCatalogScan<State: Sendable>: Sendable {
	let states: [State]
	let presentPackageNames: Set<String>
}

struct PackageLibraryStore<ID: Hashable & Comparable & Sendable, State: Sendable>: @unchecked Sendable {
	let directory: URL
	let packageURL: @Sendable (ID) -> URL
	let identifier: @Sendable (State) -> ID
	let loadPackage: @Sendable (URL) throws -> State
	let loadCatalogPackage: @Sendable (URL) throws -> State
	let fileAccess: CoordinatedFileAccess
	let fileManager: FileManager

	init(
		directory: URL,
		packageURL: @escaping @Sendable (ID) -> URL,
		identifier: @escaping @Sendable (State) -> ID,
		loadPackage: @escaping @Sendable (URL) throws -> State,
		loadCatalogPackage: (@Sendable (URL) throws -> State)? = nil,
		fileManager: FileManager = .default
	) {
		self.directory = directory
		self.packageURL = packageURL
		self.identifier = identifier
		self.loadPackage = loadPackage
		self.loadCatalogPackage = loadCatalogPackage ?? loadPackage
		self.fileAccess = CoordinatedFileAccess(fileManager: fileManager)
		self.fileManager = fileManager
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
		for candidateURL in entries {
			guard !excludedNames.contains(candidateURL.lastPathComponent) else { continue }
			presentPackageNames.insert(candidateURL.lastPathComponent)
			guard (try? candidateURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
			guard let state = try? fileAccess.read(at: candidateURL, { try loadCatalogPackage($0) }) else { continue }
			let id = identifier(state)
			guard candidateURL.lastPathComponent == packageURL(id).lastPathComponent else { continue }
			states.append(state)
		}
		return .init(
			states: states.sorted { identifier($0) < identifier($1) },
			presentPackageNames: presentPackageNames
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

	func delete(id: ID) throws {
		try prepareDirectory()
		try fileAccess.removeItem(at: packageURL(id))
	}

	private func prepareDirectory() throws {
		try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
	}
}
