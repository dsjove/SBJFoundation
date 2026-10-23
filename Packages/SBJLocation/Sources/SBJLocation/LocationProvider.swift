import CoreLocation

/// Location capability used by clients that need an eagerly acquired, cached
/// location without depending on a concrete Core Location implementation.
public protocol LocationProvider: AnyObject {
	var authorizationStatus: CLAuthorizationStatus { get }
	var currentLocation: CLLocation? { get }
	var canGetLocation: Bool { get }

	/// Observes authorization changes on the main actor and immediately delivers
	/// the current status.
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
