import Foundation

/// RAII owner for an `NSMetadataQuery` watching one iCloud Documents subtree.
/// Creating the monitor starts observation when iCloud is available; releasing it
/// stops the query, removes observers, and cancels pending callbacks.
@MainActor
final class UbiquitousDirectoryMonitor {
	enum Change {
		case all
		case urls(Set<URL>)
	}

	private let query = NSMetadataQuery()
	private var observers: [NSObjectProtocol] = []
	private let directoryURL: () -> URL
	private let onChange: (Change) -> Void
	private var queryStarted = false
	private var pendingChange: DispatchWorkItem?
	private var pendingURLs: Set<URL> = []
	private var pendingFullRefresh = false

	init(directoryURL: @escaping () -> URL, onChange: @escaping (Change) -> Void) {
		self.directoryURL = directoryURL
		self.onChange = onChange

		let center = NotificationCenter.default
		observers.append(center.addObserver(
			forName: .NSUbiquityIdentityDidChange,
			object: nil,
			queue: .main
		) { [weak self] _ in
			MainActor.assumeIsolated {
				self?.restartQuery()
				self?.schedule(.all)
			}
		})

		// Finishing the initial gather establishes the baseline. The library has
		// already performed its initial catalog load, so refreshing here would
		// immediately repeat that work.
		observers.append(center.addObserver(
			forName: .NSMetadataQueryDidUpdate,
			object: query,
			queue: .main
		) { [weak self] notification in
			// Notification is not Sendable. Consume it in the observer callback
			// before entering MainActor isolation, and carry only Sendable URLs
			// across the boundary.
			let itemURLs = Self.changedItemURLs(from: notification)
			MainActor.assumeIsolated {
				guard let self else { return }
				let urls = self.changedTopLevelURLs(from: itemURLs)
				guard !urls.isEmpty else { return }
				self.schedule(.urls(urls))
			}
		})
		startQueryIfAvailable()
	}

	private func startQueryIfAvailable() {
		guard !queryStarted, FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil else { return }
		query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
		query.predicate = NSPredicate(format: "%K BEGINSWITH %@", NSMetadataItemPathKey, directoryURL().path)
		query.notificationBatchingInterval = 0.5
		queryStarted = query.start()
	}

	nonisolated private static func changedItemURLs(from notification: Notification) -> [URL] {
		let keys = [
			NSMetadataQueryUpdateAddedItemsKey,
			NSMetadataQueryUpdateChangedItemsKey,
			NSMetadataQueryUpdateRemovedItemsKey
		]
		var result: [URL] = []

		for key in keys {
			guard let items = notification.userInfo?[key] as? [NSMetadataItem] else { continue }
			for item in items {
				guard let itemURL = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }
				result.append(itemURL)
			}
		}
		return result
	}

	private func changedTopLevelURLs(from itemURLs: [URL]) -> Set<URL> {
		let root = directoryURL().standardizedFileURL
		var result: Set<URL> = []

		for itemURL in itemURLs {
			guard let topLevel = topLevelURL(containing: itemURL, under: root) else { continue }
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

	private func schedule(_ change: Change) {
		switch change {
		case .all:
			pendingFullRefresh = true
			pendingURLs.removeAll()
		case .urls(let urls):
			guard !pendingFullRefresh else { break }
			pendingURLs.formUnion(urls)
		}

		pendingChange?.cancel()
		let work = DispatchWorkItem { [weak self] in
			MainActor.assumeIsolated {
				guard let self else { return }
				if self.pendingFullRefresh {
					self.pendingFullRefresh = false
					self.pendingURLs.removeAll()
					self.onChange(.all)
				} else {
					let urls = self.pendingURLs
					self.pendingURLs.removeAll()
					guard !urls.isEmpty else { return }
					self.onChange(.urls(urls))
				}
			}
		}
		pendingChange = work
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
	}

	private func restartQuery() {
		if queryStarted { query.stop() }
		queryStarted = false
		startQueryIfAvailable()
	}

	isolated deinit {
		pendingChange?.cancel()
		if queryStarted { query.stop() }
		observers.forEach(NotificationCenter.default.removeObserver)
	}
}
