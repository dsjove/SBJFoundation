import Foundation
import Testing
@testable import SBJCamera

@Test func cameraValueTypesRoundTrip() throws {
    let position = CameraPosition.front
    #expect(try JSONDecoder().decode(CameraPosition.self, from: JSONEncoder().encode(position)) == position)
    let flash = CameraFlashMode.auto
    #expect(try JSONDecoder().decode(CameraFlashMode.self, from: JSONEncoder().encode(flash)) == flash)
}


#if os(iOS) || os(macOS)
import SwiftUI

@MainActor
@Test func cameraPickerPublicAPI() {
    // Compile-time API parity check. iOS resolves this binding to UIImage,
    // while native macOS resolves it to NSImage.
    let binding = Binding<CameraPickerImage?>(get: { nil }, set: { _ in })
    _ = CameraPickerView(image: binding)
    _ = CameraPickerView { (_: CameraPickerImage?) in }
    _ = CameraPickerView.isAvailable
}
#endif
