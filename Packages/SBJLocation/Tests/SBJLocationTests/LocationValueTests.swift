import CoreLocation
import Foundation
import Testing
@testable import SBJLocation

private func makeLocation(
    latitude: Double = 38.6,
    longitude: Double = -90.2,
    horizontalAccuracy: Double = 12,
    timestamp: Date = Date(timeIntervalSince1970: 1_700_000_000)
) -> CLLocation {
    CLLocation(
        coordinate: .init(latitude: latitude, longitude: longitude),
        altitude: 200,
        horizontalAccuracy: horizontalAccuracy,
        verticalAccuracy: 25,
        course: 90,
        speed: 3,
        timestamp: timestamp
    )
}

@Test func locationValuePreservesFixMeasurements() throws {
    let original = makeLocation()
    let value = LocationValue(original)
    let encoded = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(LocationValue.self, from: encoded)
    let rebuilt = decoded.location
    #expect(decoded == value)
    #expect(rebuilt.coordinate.latitude == original.coordinate.latitude)
    #expect(rebuilt.coordinate.longitude == original.coordinate.longitude)
    #expect(rebuilt.altitude == original.altitude)
    #expect(rebuilt.horizontalAccuracy == original.horizontalAccuracy)
    #expect(rebuilt.verticalAccuracy == original.verticalAccuracy)
    #expect(rebuilt.course == original.course)
    #expect(rebuilt.speed == original.speed)
    #expect(rebuilt.timestamp == original.timestamp)
}

@Test func locationValueContentRepresentsUsablePosition() {
    let valid = LocationValue(makeLocation(latitude: 0, longitude: 0, horizontalAccuracy: 0))
    #expect(valid.hasContent) // (0, 0) is not a missing-location sentinel.
    let unknown = LocationValue(makeLocation(horizontalAccuracy: -1))
    #expect(!unknown.hasContent)
    #expect(!LocationValue(makeLocation(latitude: 95)).hasContent)
    #expect(!LocationValue(makeLocation(horizontalAccuracy: .infinity)).hasContent)
    // Serializing an unavailable fix should not silently substitute a location.
    #expect(unknown.location.horizontalAccuracy == -1)
}
