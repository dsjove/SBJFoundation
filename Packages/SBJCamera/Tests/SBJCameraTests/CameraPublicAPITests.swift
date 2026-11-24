import Testing
@testable import SBJCamera

@Suite("Camera selection")
struct CameraSelectionTests {
    @Test func validatesPreferredPositionWithFallbacks() {
        let dual = CameraAvailability(present: [.back, .front])
        #expect(CameraPosition.front.validated(by: dual) == .front)
        #expect(CameraPosition.unspecified.validated(by: dual) == .back)

        let mac = CameraAvailability(present: [.unspecified])
        #expect(CameraPosition.back.validated(by: mac) == .unspecified)
        #expect(CameraPosition.back.validated(by: .init()) == .unspecified)
    }

    @Test func cameraCyclingUsesOnlyAvailablePositions() {
        let dual = CameraAvailability(present: [.back, .front])
        #expect(CameraPosition.back.next(by: dual) == .front)
        #expect(CameraPosition.front.next(by: dual) == .back)

        let single = CameraAvailability(present: [.unspecified])
        #expect(CameraPosition.unspecified.next(by: single) == .unspecified)
    }
}

@Suite("Flash selection")
struct FlashSelectionTests {
    @Test func skipsUnavailableFlashModes() {
        let availability = FlashAvailability(present: [.off, .torch])
        #expect(CameraFlashMode.auto.validated(by: availability) == .torch)
        #expect(CameraFlashMode.torch.next(by: availability) == .off)
        #expect(CameraFlashMode.off.next(by: availability) == .torch)
        #expect(CameraFlashMode.on.validated(by: .init(present: [])) == .off)
    }

    @Test func distinguishesFlashFromTorch() {
        #expect(!FlashAvailability(present: [.off, .torch]).hasFlash)
        #expect(FlashAvailability(present: [.off, .torch]).hasTorch)
        #expect(FlashAvailability(present: [.off, .auto]).hasFlash)
    }
}
