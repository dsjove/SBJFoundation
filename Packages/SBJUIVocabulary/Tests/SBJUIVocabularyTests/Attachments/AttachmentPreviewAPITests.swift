#if (canImport(QuickLook) && canImport(UIKit) && !os(visionOS)) || (os(macOS) && canImport(QuickLookUI))
import XCTest
import SwiftUI
@testable import SBJUIVocabulary

@MainActor
final class AttachmentPreviewAPITests: XCTestCase {
    func testSharedPreviewInitializer() {
        let url = URL(fileURLWithPath: "/tmp/example.pdf")
        let preview = AttachmentPreviewSheet(url: url, displayName: "Example")
        XCTAssertEqual(preview.url, url)
        XCTAssertEqual(preview.displayName, "Example")
        let _: any View = preview
    }
}
#endif
