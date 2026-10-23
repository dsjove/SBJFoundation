import Foundation
import SwiftUI
import Testing
@testable import SBJImage

@Suite("Image reference View APIs")
struct ImageReferenceViewAPITests {
    @MainActor
    @Test func imageReferenceInitializersRetainEstablishedSurface() {
        _ = Image(.system("star"))
        _ = Image(.asset("logo"))
        _ = Image(.asset("logo", bundle: Bundle.main))
        _ = Image(.resource("ThumbnailDocument.png"))
        _ = Image(.resource(name: "ThumbnailDocument", extension: "png", bundle: Bundle.main))
        _ = Image(.file(URL(fileURLWithPath: "/tmp/image.png")))
        _ = Label("Favorite", image: .system("star"))
        _ = Label("Portrait", image: .file(URL(fileURLWithPath: "/tmp/image.png")))
    }
}
