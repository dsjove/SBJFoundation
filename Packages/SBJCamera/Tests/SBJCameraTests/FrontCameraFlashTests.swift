import Testing
@testable import SBJCamera

@MainActor
@Suite("Simulated front-camera flash")
struct FrontCameraFlashTests {
    @Test func performsCaptureAndRestoresFlash() async {
        let flash = FrontCameraFlash(exposureDelay: .zero, shutterHoldDuration: .zero)
        var captures = 0
        await flash.perform { captures += 1 }
        #expect(captures == 1)
        #expect(!flash.isActive)
    }

    @Test func cancellationPreventsPendingCapture() async {
        let flash = FrontCameraFlash(exposureDelay: .seconds(1), shutterHoldDuration: .zero)
        var captures = 0
        let operation = Task { @MainActor in
            await flash.perform { captures += 1 }
        }
        // Await the coordinator's own state change instead of relying on a fixed delay.
        while !flash.isActive { await Task.yield() }
        flash.cancel()
        operation.cancel()
        await operation.value
        #expect(captures == 0)
        #expect(!flash.isActive)
    }

}
