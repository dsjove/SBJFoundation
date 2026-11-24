import CoreLocation
import Foundation
import Observation
import SBJLocalization

/// Eager Core Location provider intended for clients that need a location
/// immediately at the point of use. It begins authorization/acquisition as soon
/// as it is created and retains the newest valid location as a cache.
@Observable
final class LocationManager: NSObject, LocationProvider, @unchecked Sendable {
	private let manager: CLLocationManager
	private(set) var authorizationStatus: CLAuthorizationStatus
	private(set) var currentLocation: CLLocation?
	private(set) var canGetLocation: Bool

	override init() {
		let manager = CLLocationManager()
		self.manager = manager
		let authorizationStatus = manager.authorizationStatus
		self.authorizationStatus = authorizationStatus
		self.canGetLocation = Self.canGetLocation(for: authorizationStatus)
		self.currentLocation = Self.canGetLocation(for: authorizationStatus) ? Self.validLocation(manager.location) : nil
		super.init()

		manager.delegate = self
		manager.desiredAccuracy = kCLLocationAccuracyBest

		// Defer one turn so clients can finish constructing while still beginning
		// authorization/location acquisition at application startup.
		DispatchQueue.main.async { [weak self] in
			self?.requestAccessAndStart()
		}
	}

	@MainActor
	private func requestAccessAndStart() {
		authorizationStatus = manager.authorizationStatus
		canGetLocation = Self.canGetLocation(for: authorizationStatus)
		if canGetLocation {
			if let cached = Self.validLocation(manager.location) { accept(cached) }
#if !os(tvOS)
			manager.startUpdatingLocation()
#endif
		} else {
			currentLocation = nil
#if !os(tvOS)
			manager.stopUpdatingLocation()
#endif
			if authorizationStatus == .notDetermined {
				manager.requestWhenInUseAuthorization()
			}
		}
	}

	@MainActor
	func observeAuthorization(
		_ change: @escaping @MainActor (CLAuthorizationStatus) -> Void
	) -> ObserveToken {
		SBJLocalization.observeValue(of: self, \.authorizationStatus) { _, status in
			change(status)
		}
	}

	static func canGetLocation(for status: CLAuthorizationStatus) -> Bool {
#if os(macOS)
		return status == .authorizedAlways
#else
		switch status {
		case .authorizedAlways, .authorizedWhenInUse:
			return true
		case .notDetermined, .restricted, .denied:
			return false
		@unknown default:
			return false
		}
#endif
	}

	/// Core Location uses a negative horizontal accuracy for an invalid fix.
	static func validLocation(_ location: CLLocation?) -> CLLocation? {
		guard let location,
			location.horizontalAccuracy.isFinite,
			location.horizontalAccuracy >= 0,
			CLLocationCoordinate2DIsValid(location.coordinate) else { return nil }
		return location
	}

	/// A batch is not guaranteed to be ordered by timestamp. Choose its freshest
	/// valid fix, then compare it with the cached fix in `accept(_:)`.
	static func newestValidLocation(in locations: [CLLocation]) -> CLLocation? {
		locations.compactMap(validLocation).max { $0.timestamp < $1.timestamp }
	}

	@MainActor
	private func accept(_ location: CLLocation) {
		guard let currentLocation else {
			self.currentLocation = location
			return
		}
		if location.timestamp >= currentLocation.timestamp {
			self.currentLocation = location
		}
	}
}

extension LocationManager: CLLocationManagerDelegate {
	func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
		let status = manager.authorizationStatus
		let cached = Self.validLocation(manager.location)
		DispatchQueue.main.async { [weak self] in
			guard let self else { return }
			self.authorizationStatus = status
			self.canGetLocation = Self.canGetLocation(for: status)
			if self.canGetLocation {
				if let cached { self.accept(cached) }
#if !os(tvOS)
				self.manager.startUpdatingLocation()
#endif
			} else {
				self.currentLocation = nil
#if !os(tvOS)
				self.manager.stopUpdatingLocation()
#endif
			}
		}
	}

	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		guard let latest = Self.newestValidLocation(in: locations) else { return }
		DispatchQueue.main.async { [weak self] in
			guard let self, self.canGetLocation else { return }
			self.accept(latest)
		}
	}
}
