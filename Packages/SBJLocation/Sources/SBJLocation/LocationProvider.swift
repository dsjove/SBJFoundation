import CoreLocation
import SBJLocalization

/// Location capability used by clients that need an eagerly acquired, cached
/// location without depending on a concrete Core Location implementation.
public protocol LocationProvider: AnyObject {
	/// Most recently observed authorization state.
	var authorizationStatus: CLAuthorizationStatus { get }
	/// Freshest accepted fix, or nil when no valid authorized fix is available.
	/// This is a cache, not a one-shot location request.
	var currentLocation: CLLocation? { get }
	/// Whether the current authorization permits location updates.
	var canGetLocation: Bool { get }

	/// Observes authorization changes on the main actor. The current status is
	/// delivered asynchronously upon registration, followed by changes.
	/// Retain the returned token for as long as observation is desired; release
	/// or cancel it to stop callbacks.
	@MainActor
	func observeAuthorization(
		_ change: @escaping @MainActor (CLAuthorizationStatus) -> Void
	) -> ObserveToken
}

/// Creates the standard Core Location-backed provider while keeping its
/// implementation private to SBJLocation.
public enum LocationFactory {
	@MainActor
	public static func make() -> any LocationProvider {
		LocationManager()
	}
}
