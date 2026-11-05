#if canImport(UIKit) || canImport(AppKit)
import Testing
@testable import SBJLocalization

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@Test func platformImageAliasAndResize() {
    #if canImport(UIKit) && !os(watchOS)
    let image = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 60)).image { _ in }
    let scaled: SBJImage = image.resized(toFit: CGSize(width: 50, height: 50))
    #expect(scaled.size.width == 50)
    #expect(scaled.size.height == 25)
    #elseif canImport(AppKit)
    let image = NSImage(size: CGSize(width: 120, height: 60))
    let scaled: SBJImage = image.resized(toFit: CGSize(width: 50, height: 50))
    #expect(scaled.size.width == 50)
    #expect(scaled.size.height == 25)
    #endif
}

@Test func nativeSystemSymbol() {
    let symbol = SBJSymbol.system("star")
    #expect(symbol.nativeImage != nil)
}
#endif

@Test func platformImagePresentationAdapters() {
    guard let image = SBJSymbol.system("star").nativeImage else {
        Issue.record("System symbol is unavailable")
        return
    }
    _ = image.sbjSwiftUIImage
    #expect(image.sbjCGImage == nil || image.sbjCGImage!.width > 0)
}
