import Foundation

/// Owns the metadata query for one iCloud Documents subtree.
///
/// The metadata query is the authoritative source for which cloud packages
/// exist. File-system enumeration is deliberately not used for the iCloud
/// catalog because metadata can arrive before package contents are downloaded.
@MainActor
final class UbiquitousDirectoryMonitor {
	enum Change {
		case snapshot(Set<URL>)
	}

	private let query = NSMetadataQuery()
	private var observers: [NSObjectProtocol] = []
	private let directoryURL: () -> URL
	private let packageExtension: String
	private let onChange: (Change) -> Void
	private let onIdentityChange: () -> Void
	private var queryStarted = false
	private var pendingChange: DispatchWorkItem?
	private var initialURLs: Set<URL>?
	private var initialWaiters: [CheckedContinuation<Set<URL>, Never>] = []
	private var identityFingerprint: Data?

	init(
		directoryURL: @escaping () -> URL,
		packageExtension: String,
		onIdentityChange: @escaping () -> Void,
		onChange: @escaping (Change) -> Void
	) {
		self.directoryURL = directoryURL
		self.packageExtension = packageExtension
		self.onIdentityChange = onIdentityChange
		self.onChange = onChange
		self.identityFingerprint = Self.currentIdentityFingerprint()

		let center = NotificationCenter.default
		observers.append(center.addObserver(
			forName: .NSUbiquityIdentityDidChange,
			object: nil,
			queue: .main
		) { [weak self] _ in
			MainActor.assumeIsolated {
				guard let self else { return }
				let fingerprint = Self.currentIdentityFingerprint()
				if fingerprint != self.identityFingerprint {
					self.identityFingerprint = fingerprint
					self.onIdentityChange()
				}
				self.restartQuery()
			}
		})

		observers.append(center.addObserver(
			forName: .NSMetadataQueryDidFinishGathering,
			object: query,
			queue: .main
		) { [weak self] _ in
			MainActor.assumeIsolated {
				guard let self else { return }
				let urls = self.currentTopLevelPackageURLs()
				self.finishInitialGather(with: urls)
				self.schedule(urls)
			}
		})

		observers.append(center.addObserver(
			forName: .NSMetadataQueryDidUpdate,
			object: query,
			queue: .main
		) { [weak self] _ in
			MainActor.assumeIsolated {
				guard let self else { return }
				self.schedule(self.currentTopLevelPackageURLs())
			}
		})

		startQueryIfAvailable()
	}

	func initialPackageURLs() async -> Set<URL> {
		if let initialURLs { return initialURLs }
		guard queryStarted else { return [] }
		return await withCheckedContinuation { continuation in
			initialWaiters.append(continuation)
		}
	}

	func currentPackageURLs() -> Set<URL> {
		currentTopLevelPackageURLs()
	}

	private func startQueryIfAvailable() {
		guard !queryStarted else { return }
		query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
		query.predicate = NSPredicate(format: "%K BEGINSWITH %@", NSMetadataItemPathKey, directoryURL().path)
		query.notificationBatchingInterval = 0.5
		queryStarted = query.start()
		if !queryStarted { finishInitialGather(with: []) }
	}

	private func currentTopLevelPackageURLs() -> Set<URL> {
		let root = directoryURL().standardizedFileURL
		var result: Set<URL> = []
		for case let item as NSMetadataItem in query.results {
			guard let itemURL = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
				let topLevel = topLevelURL(containing: itemURL, under: root),
				topLevel.pathExtension.caseInsensitiveCompare(packageExtension) == .orderedSame
			else { continue }
			result.insert(topLevel)
		}
		return result
	}

	private func topLevelURL(containing itemURL: URL, under root: URL) -> URL? {
		let itemComponents = itemURL.standardizedFileURL.pathComponents
		let rootComponents = root.pathComponents
		guard itemComponents.count > rootComponents.count,
			Array(itemComponents.prefix(rootComponents.count)) == rootComponents
		else { return nil }
		return root.appendingPathComponent(itemComponents[rootComponents.count], isDirectory: true)
	}

	private func finishInitialGather(with urls: Set<URL>) {
		if initialURLs == nil { initialURLs = urls }
		let waiters = initialWaiters
		initialWaiters.removeAll()
		for waiter in waiters { waiter.resume(returning: urls) }
	}

	private func schedule(_ urls: Set<URL>) {
		pendingChange?.cancel()
		let work = DispatchWorkItem { [weak self] in
			MainActor.assumeIsolated {
				guard let self else { return }
				self.onChange(.snapshot(urls))
			}
		}
		pendingChange = work
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
	}

	private func restartQuery() {
		if queryStarted { query.stop() }
		queryStarted = false
		initialURLs = nil
		startQueryIfAvailable()
	}

	isolated deinit {
		pendingChange?.cancel()
		if queryStarted { query.stop() }
		for waiter in initialWaiters { waiter.resume(returning: []) }
		observers.forEach(NotificationCenter.default.removeObserver)
	}
	private static func currentIdentityFingerprint() -> Data? {
		guard let token = FileManager.default.ubiquityIdentityToken else { return nil }
		return try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: false)
	}
}
