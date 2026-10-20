import Foundation
import Testing
@testable import SBJCamera

@Test func cameraValueTypesRoundTrip() throws {
    let position = CameraPosition.front
    #expect(try JSONDecoder().decode(CameraPosition.self, from: JSONEncoder().encode(position)) == position)
    let flash = CameraFlashMode.auto
    #expect(try JSONDecoder().decode(CameraFlashMode.self, from: JSONEncoder().encode(flash)) == flash)
}
