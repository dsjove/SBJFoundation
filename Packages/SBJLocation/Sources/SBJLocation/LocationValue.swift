import CoreLocation
import Foundation

public struct LocationValue: Codable, Equatable {
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
