import CoreLocation
import Foundation
import Testing
@testable import SBJLocation

@Test func LocationValueRoundTrip() throws {
    let original = CLLocation(latitude: 38.6, longitude: -90.2)
    let encoded = try JSONEncoder().encode(LocationValue(original))
    let decoded = try JSONDecoder().decode(LocationValue.self, from: encoded)
    #expect(decoded.location.coordinate.latitude == original.coordinate.latitude)
    #expect(decoded.location.coordinate.longitude == original.coordinate.longitude)
}
