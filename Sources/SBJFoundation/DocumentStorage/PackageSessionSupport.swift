#if !os(watchOS)
import Foundation

public enum PackagePersistenceOperation: String, Equatable, Sendable {
	case create
	case autosave
	case explicitSave
	case editCompleted
	case documentSwitch
	case duplication
	case appSceneChange
	case applicationTermination
	case close
	case conflictResolution
	case recreate
}

public enum PackageDocumentPersistenceStatus: String, Equatable, Sendable, CustomStringConvertible {
	case saved = "Saved"
	case dirty = "Dirty"
	case saving = "Saving"
	case failed = "failed"

	public var description: String {
		self.rawValue
	}

	public var image: ImageReference {
		switch self {
		case .saved:
			.system("checkmark.circle")
		case .dirty:
			.system("asterisk.circle")
		case .saving:
			.system("arrow.triangle.2.circlepath")
		case .failed:
			.system("exclamationmark.triangle")
		}
	}
}

public struct PackagePersistenceFailure: LocalizedError, Equatable, Sendable {
	public let operation: PackagePersistenceOperation
	public let occurredAt: Date
	public let message: String
	public let domain: String
	public let code: Int
	public let filePath: String

	public init(error: Error, operation: PackagePersistenceOperation, fileURL: URL, occurredAt: Date = .now) {
		let nsError = error as NSError
		self.operation = operation
		self.occurredAt = occurredAt
		self.message = error.localizedDescription
		self.domain = nsError.domain
		self.code = nsError.code
		self.filePath = fileURL.path
	}

	public var errorDescription: String? { message }

	public var diagnosticDescription: String {
		"\(operation.rawValue) failed [\(domain) \(code)] at \(filePath): \(message)"
	}
}


public struct PackagePersistenceBarrierError: LocalizedError, Sendable {
	public let failures: [PackagePersistenceFailure]

	public init(failures: [PackagePersistenceFailure]) {
		self.failures = failures
	}

	public var errorDescription: String? {
		guard !failures.isEmpty else { return nil }
		if failures.count == 1 { return failures[0].localizedDescription }
		return "\(failures.count) documents could not be saved."
	}
}

public struct PackageDocumentPersistenceState: Equatable, Sendable {
	public let status: PackageDocumentPersistenceStatus
	public let currentChange: Int
	public let persistedChange: Int
	public let lastSuccessfulSaveAt: Date?
	public let lastFailure: PackagePersistenceFailure?

	public init(
		status: PackageDocumentPersistenceStatus = .saved,
		currentChange: Int = 0,
		persistedChange: Int = 0,
		lastSuccessfulSaveAt: Date? = nil,
		lastFailure: PackagePersistenceFailure? = nil
	) {
		self.status = status
		self.currentChange = currentChange
		self.persistedChange = persistedChange
		self.lastSuccessfulSaveAt = lastSuccessfulSaveAt
		self.lastFailure = lastFailure
	}
}

/// Platform-neutral events emitted by an active package session.
enum PackageSessionEvent<Snapshot: PackageDocumentSnapshot>: @unchecked Sendable {
	case loaded(Snapshot)
	case moved(URL)
	case deleted
	case conflict
	case saveStarted(change: Int, operation: PackagePersistenceOperation)
	case saveSucceeded(change: Int, operation: PackagePersistenceOperation, at: Date)
	case saveFailed(change: Int, failure: PackagePersistenceFailure)
	case error(any Error)
	case warning(PackageDocumentWriteWarning)
}

func resolvePackageFileVersions(at url: URL, keepingCurrent: Bool) throws {
	var coordinationError: NSError?
	var operationError: Error?
	NSFileCoordinator().coordinate(
		writingItemAt: url,
		options: [],
		error: &coordinationError
	) { coordinatedURL in
		do {
			let versions = NSFileVersion.unresolvedConflictVersionsOfItem(at: coordinatedURL) ?? []
			if !keepingCurrent, let external = versions.max(by: {
				($0.modificationDate ?? .distantPast) < ($1.modificationDate ?? .distantPast)
			}) {
				_ = try external.replaceItem(at: coordinatedURL)
			}
			for version in versions { version.isResolved = true }
			try NSFileVersion.removeOtherVersionsOfItem(at: coordinatedURL)
		} catch {
			operationError = error
		}
	}
	if let coordinationError { throw coordinationError }
	if let operationError { throw operationError }
}

#endif
