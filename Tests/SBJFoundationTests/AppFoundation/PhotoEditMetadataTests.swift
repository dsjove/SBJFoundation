import Testing
@testable import SBJFoundation
#if !os(watchOS) && !os(tvOS) && canImport(UIKit)

@Suite("Photo edit metadata")
struct PhotoEditMetadataTests {
    @Test func editPropertiesExposeMetadata() {
        #expect(PhotoCropState.propertyInfo(for: \PhotoCropState.option) != nil)
        #expect(PhotoCropState.propertyInfo(for: \PhotoCropState.swapsDimensions) != nil)
        #expect(PhotoMirrorState.propertyInfo(for: \PhotoMirrorState.horizontal) != nil)
        #expect(PhotoRotation.propertyInfo(for: \PhotoRotation.fineDegrees) != nil)
    }
}
#endif
