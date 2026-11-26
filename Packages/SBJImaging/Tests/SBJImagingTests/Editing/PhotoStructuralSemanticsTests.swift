import Testing
import SBJStructure
@testable import SBJImaging

@Test func photoAtomicValuesPreserveStructuralMembers() {
    #expect(SBJStructuralType.isAtomic(PhotoRotation.self))
    #expect(SBJStructuralType.isAtomic(PhotoMarkupCanvasSize.self))
    #expect(Set(PhotoRotation.sbjProperties.map(\.sourceName)) == ["quarterTurns", "fineDegrees"])
    #expect(Set(PhotoMarkupCanvasSize.sbjProperties.map(\.sourceName)) == ["width", "height"])
    let rotation = PhotoRotation(quarterTurns: 1, fineDegrees: 5)
    #expect(rotation.presentedValue == "Rotation 95.0°")
    #expect(!rotation.sbjStructuralEquals(PhotoRotation(quarterTurns: 1, fineDegrees: 6)))
    let size = PhotoMarkupCanvasSize(width: 640, height: 480)
    #expect(size.presentedValue == "640.0 × 480.0")
    #expect(!size.sbjStructuralEquals(PhotoMarkupCanvasSize(width: 640, height: 481)))
}

@Test func independentlyEditablePhotoSettingsRemainCompound() {
    #expect(!SBJStructuralType.isAtomic(PhotoEditGeometry.self))
    #expect(!SBJStructuralType.isAtomic(PhotoColorAdjustments.self))
    #expect(!SBJStructuralType.isAtomic(PhotoCropState.self))
    #expect(!SBJStructuralType.isAtomic(PhotoMirrorState.self))
    #expect(!SBJStructuralType.isAtomic(NormalizedPhotoOffset.self))
}

@Test func photoSummariesReflectActualSettings() {
    #expect(PhotoColorAdjustments().presentedValue == "No color adjustments")
    var adjusted = PhotoColorAdjustments()
    adjusted.exposure = 0.5
    #expect(adjusted.presentedValue == "Color adjustments applied")
    #expect(PhotoCropState(option: .fourThree, freeAspectRatio: 2, swapsDimensions: true).presentedValue == "3:4 crop")
    #expect(PhotoCropState(option: .free, freeAspectRatio: 2).presentedValue == "Free crop, aspect ratio 2.0")
}
