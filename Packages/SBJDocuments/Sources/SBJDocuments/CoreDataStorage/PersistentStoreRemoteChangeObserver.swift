import CoreData
import Foundation

/// Keeps the Core Data remote-store notification plumbing out of individual
/// apps while leaving the actual reconciliation policy with the app.
///
/// TODO(CoreDataStorage strategy): If the remaining CloudKit apps show the same
/// cache/root/repair refresh sequence, promote that sequence into a reusable
/// coordinator instead of having each app register parallel callbacks.
@MainActor
public final class PersistentStoreRemoteChangeObserver {
    private var observer: NSObjectProtocol?

    public init(action: @escaping @MainActor () -> Void) {
        observer = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                action()
            }
        }
    }

	isolated deinit {
		if let observer {
			NotificationCenter.default.removeObserver(observer)
		}
	}
}
