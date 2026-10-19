import Foundation

public extension URL {
	/// Performs a synchronous operation while this URL's security-scoped access is active.
	///
	/// URLs that do not require a security scope remain usable; `stopAccessing...` is
	/// balanced only when `startAccessing...` actually started access.
	func withSecurityScopedAccess<T>(_ operation: (URL) throws -> T) rethrows -> T {
#if canImport(Darwin)
		let isAccessing = startAccessingSecurityScopedResource()
		defer {
			if isAccessing {
				stopAccessingSecurityScopedResource()
			}
		}
#endif
		return try operation(self)
	}
}
