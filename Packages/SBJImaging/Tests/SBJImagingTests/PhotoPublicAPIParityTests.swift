#if os(macOS) || os(iOS)
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Testing
import SBJFileResources
@testable import SBJImaging

@Suite("Photo public API parity")
struct PhotoPublicAPIParityTests {
    @MainActor
    @Test func imagePresentationAndWorkflowInitializersAreAvailable() {
        let resource = Binding<SBJResourceContent?>(get: { nil }, set: { _ in })
        _ = PhotoDisplayView(resource: nil)
        _ = PhotoThumbnailView(resource: resource)
        _ = PhotoMenu(resource: resource)
        _ = PhotoMenu(resource: resource) { Image(systemName: "photo") }
        _ = PhotoLibrary.isAuthorized
    }

    @MainActor
    @Test func viewerAndEditorInterfacesAreAvailable() {
        // The decoded value is intentionally invalid; these failable
        // initializers still exercise their public signatures at compile time.
        let invalid = SBJResourceContent(data: Data(), contentType: .png)
        _ = PhotoViewer(resource: invalid, title: "Test", maximumScale: 8)
        _ = PhotoEditor(resource: invalid, title: "Test", options: .default,
                        allowsUnchangedCompletion: false) { (_: SBJResourceContent?) in }
    }
}
#endif
