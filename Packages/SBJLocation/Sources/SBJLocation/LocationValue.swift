import CoreLocation
import Foundation
import SBJLocalization

/// A serializable location fix. Accuracy values can be negative when Core Location
/// does not know them; an unknown horizontal accuracy is not a usable fix.
/// Zero latitude and longitude are valid coordinates and are never used as a
/// missing-value sentinel.
public struct LocationValue: Codable, Equatable, HasContentCheckable {
	public var latitude: CLLocationDegrees
	public var longitude: CLLocationDegrees
	public var altitude: CLLocationDistance
	public var horizontalAccuracy: CLLocationAccuracy
	public var verticalAccuracy: CLLocationAccuracy
	public var course: CLLocationDirection
	public var courseAccuracy: CLLocationDirectionAccuracy
	public var speed: CLLocationSpeed
	public var speedAccuracy: CLLocationSpeedAccuracy
	public var timestamp: Date

	public init(_ location: CLLocation) {
		latitude = location.coordinate.latitude
		longitude = location.coordinate.longitude
		altitude = location.altitude
		horizontalAccuracy = location.horizontalAccuracy
		verticalAccuracy = location.verticalAccuracy
		course = location.course
		courseAccuracy = location.courseAccuracy
		speed = location.speed
		speedAccuracy = location.speedAccuracy
		timestamp = location.timestamp
	}

	/// A fix has meaningful location content only when its coordinate and
	/// horizontal accuracy represent a usable position. Other measurements,
	/// such as altitude, course, and speed, may legitimately be unknown.
	public var hasContent: Bool {
		horizontalAccuracy.isFinite && horizontalAccuracy >= 0 &&
		CLLocationCoordinate2DIsValid(.init(latitude: latitude, longitude: longitude))
	}

	/// Converts the stored values back into a Core Location object. Does not
	/// require `hasContent` to be true, preserving unknown accuracy metadata.
	public var location: CLLocation {
		CLLocation(
			coordinate: .init(latitude: latitude, longitude: longitude),
			altitude: altitude,
			horizontalAccuracy: horizontalAccuracy,
			verticalAccuracy: verticalAccuracy,
			course: course,
			courseAccuracy: courseAccuracy,
			speed: speed,
			speedAccuracy: speedAccuracy,
			timestamp: timestamp
		)
	}
}
