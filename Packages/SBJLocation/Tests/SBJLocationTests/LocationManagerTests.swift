import CoreLocation
import Foundation
import Testing
@testable import SBJLocation

private func fix(_ date: TimeInterval, accuracy: CLLocationAccuracy = 10) -> CLLocation {
    CLLocation(coordinate: .init(latitude: 38.6, longitude: -90.2),
               altitude: 0, horizontalAccuracy: accuracy, verticalAccuracy: -1,
               course: -1, speed: -1,
               timestamp: Date(timeIntervalSince1970: date))
}

@Test func locationSelectionRejectsInvalidFixes() {
    #expect(LocationManager.validLocation(nil) == nil)
    #expect(LocationManager.validLocation(fix(100, accuracy: -1)) == nil)
    #expect(LocationManager.validLocation(fix(100)) != nil)
    #expect(LocationManager.newestValidLocation(in: [fix(100, accuracy: -1)]) == nil)
}

@Test func locationSelectionUsesNewestTimestampNotLastPosition() {
    let older = fix(100)
    let newer = fix(300)
    let invalid = fix(500, accuracy: -1)
    let selected = LocationManager.newestValidLocation(in: [newer, invalid, older])
    #expect(selected?.timestamp == newer.timestamp)
}

@Test func authorizationStatusControlsPermission() {
    #expect(!LocationManager.canGetLocation(for: .notDetermined))
    #expect(!LocationManager.canGetLocation(for: .denied))
    #expect(!LocationManager.canGetLocation(for: .restricted))
    #expect(LocationManager.canGetLocation(for: .authorizedAlways))
#if !os(macOS)
    #expect(LocationManager.canGetLocation(for: .authorizedWhenInUse))
#endif
}
