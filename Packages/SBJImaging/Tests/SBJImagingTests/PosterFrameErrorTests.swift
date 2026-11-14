import Foundation
import Testing
import SBJImaging

struct PosterFrameErrorTests {
    @Test func clearFailureReportsWhichStageFailed() {
        let export = PosterFrameWriteError.exportFailed("AVFoundation export rejected the file")
        let verification = PosterFrameWriteError.verificationFailed("Artwork remains")
        let replacement = PosterFrameWriteError.replacementFailed("Permission denied")

        #expect(export.errorDescription?.contains("export") == true)
        #expect(verification.errorDescription?.contains("Artwork remains") == true)
        #expect(replacement.errorDescription?.contains("Permission denied") == true)
    }
}
