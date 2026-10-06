import Foundation

/// Reusable wrapper around coordinated file operations for documents that can
/// be changed by file providers, iCloud, or another process.
struct CoordinatedFileAccess: @unchecked Sendable {
	let fileManager: FileManager

	init(fileManager: FileManager = .default) {
		self.fileManager = fileManager
	}

	func read<T>(at url: URL, options: NSFileCoordinator.ReadingOptions = [], _ accessor: (URL) throws -> T) throws -> T {
		var coordinationError: NSError?
		var result: Result<T, Error>?
		NSFileCoordinator().coordinate(readingItemAt: url, options: options, error: &coordinationError) { coordinatedURL in
			result = Result { try accessor(coordinatedURL) }
		}
		if let coordinationError { throw coordinationError }
		guard let result else { throw CocoaError(.fileReadUnknown) }
		return try result.get()
	}

	/// Performs a coordinated read while holding security-scoped access to the
	/// supplied URL for the entire operation. This is appropriate for URLs
	/// returned by document pickers and other file-provider APIs.
	func readSecurityScoped<T>(
		at url: URL,
		options: NSFileCoordinator.ReadingOptions = [],
		_ accessor: (URL) throws -> T
	) throws -> T {
		try url.withSecurityScopedAccess { scopedURL in
			try read(at: scopedURL, options: options, accessor)
		}
	}


	func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
		guard fileManager.fileExists(atPath: sourceURL.path) else { return }
		try fileManager.createDirectory(
			at: destinationURL.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)

		var coordinationError: NSError?
		var operationError: Error?
		NSFileCoordinator().coordinate(
			writingItemAt: sourceURL,
			options: .forMoving,
			error: &coordinationError
		) { coordinatedSourceURL in
			do {
				guard fileManager.fileExists(atPath: coordinatedSourceURL.path) else { return }
				try fileManager.moveItem(at: coordinatedSourceURL, to: destinationURL)
			} catch {
				operationError = error
			}
		}
		if let coordinationError { throw coordinationError }
		if let operationError { throw operationError }
	}

	func removeItem(at url: URL) throws {
		guard fileManager.fileExists(atPath: url.path) else { return }
		var coordinationError: NSError?
		var operationError: Error?
		NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &coordinationError) { coordinatedURL in
			do {
				if fileManager.fileExists(atPath: coordinatedURL.path) {
					try fileManager.removeItem(at: coordinatedURL)
				}
			} catch {
				operationError = error
			}
		}
		if let coordinationError { throw coordinationError }
		if let operationError { throw operationError }
	}
}
