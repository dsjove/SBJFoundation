import Foundation
import Testing
@testable import SBJUIVocabulary

#if canImport(AppKit)
import AppKit

struct NativePlatformColorTests {
    @Test func appKitColorRoundTrip() {
        let native = NSColor(deviceRed: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        let value = CodableColor(color: native)
        let restored = value.nsColor.usingColorSpace(.deviceRGB)!
        #expect(abs(restored.redComponent - 0.2) < 0.001)
        #expect(abs(restored.alphaComponent - 0.8) < 0.001)
    }
}
#endif
