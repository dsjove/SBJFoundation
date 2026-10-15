import Foundation
import SBJShared

/// Copies staged export artifacts into a user-selected directory while enforcing
/// explicit collision handling.
public struct ExportDestinationService: @unchecked Sendable {
	public struct Collision: Hashable, Sendable {
		public let name: String
		init(name: String) { self.name = name }
	}

	public enum ExportResult: Sendable {
		case exported
		case needsReplacement([Collision])
	}

	enum ExportError: LocalizedError {
		case duplicateSourceName(String)
		case inaccessibleDestination
		case destinationExists(String)

		var errorDescription: String? {
			switch self {
			case .duplicateSourceName(let name):
				return "The export contains multiple items named ‘\(name)’."
			case .inaccessibleDestination:
				return "The selected export folder could not be accessed."
			case .destinationExists(let name):
				return "‘\(name)’ already exists in the selected export folder."
			}
		}
	}

	let fileManager: FileManager

	public init() {
		self.fileManager = .default
	}

	init(fileManager: FileManager) {
		self.fileManager = fileManager
	}

	public func export(
		_ sourceURLs: [URL],
		to destinationDirectory: URL,
		replacingExisting: Bool
	) throws -> ExportResult {
		try validateUniqueNames(sourceURLs)

		return try destinationDirectory.withSecurityScopedAccess { scopedDestinationDirectory in
			var isDirectory: ObjCBool = false
			guard fileManager.fileExists(
				atPath: scopedDestinationDirectory.path,
				isDirectory: &isDirectory
			), isDirectory.boolValue else {
				throw ExportError.inaccessibleDestination
			}

			let destinations = sourceURLs.map { source in
				scopedDestinationDirectory.appendingPathComponent(
					source.lastPathComponent,
					isDirectory: source.hasDirectoryPath
				)
			}

			let existingCollisions = collisions(at: destinations)
			if !replacingExisting, !existingCollisions.isEmpty {
				return .needsReplacement(existingCollisions)
			}

			do {
				for (source, destination) in zip(sourceURLs, destinations) {
					try copy(source, to: destination, replacingExisting: replacingExisting)
				}
			} catch ExportError.destinationExists {
				return .needsReplacement(collisions(at: destinations))
			}

			return .exported
		}
	}

	private func collisions(at urls: [URL]) -> [Collision] {
		urls.compactMap { fileManager.fileExists(atPath: $0.path) ? Collision(name: $0.lastPathComponent) : nil }
			.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
	}

	private func validateUniqueNames(_ urls: [URL]) throws {
		var names = Set<String>()
		for url in urls {
			let name = url.lastPathComponent
			guard names.insert(name).inserted else { throw ExportError.duplicateSourceName(name) }
		}
	}

	private func copy(_ source: URL, to destination: URL, replacingExisting: Bool) throws {
		let coordinator = NSFileCoordinator(filePresenter: nil)
		var coordinationError: NSError?
		var copyError: Error?
		let options: NSFileCoordinator.WritingOptions = replacingExisting ? .forReplacing : []

		coordinator.coordinate(writingItemAt: destination, options: options, error: &coordinationError) { coordinatedURL in
			do {
				if fileManager.fileExists(atPath: coordinatedURL.path) {
					guard replacingExisting else { throw ExportError.destinationExists(coordinatedURL.lastPathComponent) }
					try fileManager.removeItem(at: coordinatedURL)
				}
				try fileManager.copyItem(at: source, to: coordinatedURL)
			} catch {
				copyError = error
			}
		}
		if let coordinationError { throw coordinationError }
		if let copyError { throw copyError }
	}
}
