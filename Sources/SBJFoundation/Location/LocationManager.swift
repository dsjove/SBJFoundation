import SBJUIVocabulary
import CoreLocation
import SBJDataDefinition
import Foundation
import Observation

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
		self.currentLocation = Self.validLocation(manager.location)
		self.canGetLocation = Self.canGetLocation(for: authorizationStatus)
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
		if let cached = Self.validLocation(manager.location) {
			accept(cached)
		}

		switch authorizationStatus {
		case .authorizedAlways, .authorizedWhenInUse:
#if !os(tvOS)
			manager.startUpdatingLocation()
#else
			break
#endif
		case .notDetermined:
			manager.requestWhenInUseAuthorization()
		default:
			break
		}
	}

	@MainActor
	func observeAuthorization(
		_ change: @escaping @MainActor (CLAuthorizationStatus) -> Void
	) -> ObserveToken {
		SBJFoundation.observeValue(of: self, \.authorizationStatus) { _, status in
			change(status)
		}
	}

	private static func canGetLocation(for status: CLAuthorizationStatus) -> Bool {
		switch status {
		case .authorizedAlways, .authorizedWhenInUse:
			return true
		case .notDetermined, .restricted, .denied:
			return false
		@unknown default:
			return false
		}
	}

	private static func validLocation(_ location: CLLocation?) -> CLLocation? {
		guard let location, location.horizontalAccuracy >= 0 else { return nil }
		return location
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
			if let cached { self.accept(cached) }
			#if os(visionOS)
			let start = status == .authorizedWhenInUse
			#else
			let start = status == .authorizedAlways || status == .authorizedWhenInUse
			#endif
			if start {
			#if !os(tvOS)
				self.manager.startUpdatingLocation()
			#endif
			}
		}
	}

	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		guard let latest = locations.last(where: { $0.horizontalAccuracy >= 0 }) else { return }
		DispatchQueue.main.async { [weak self] in
			self?.accept(latest)
		}
	}
}
