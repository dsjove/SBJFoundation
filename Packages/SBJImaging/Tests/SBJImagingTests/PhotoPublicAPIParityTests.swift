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
        let deferred = SBJResourceSource.deferred(
            hasContent: nil, load: { nil }, save: { _ in }
        )
        _ = PhotoMenu(source: deferred)
        _ = PhotoMenu(source: deferred) { Image(systemName: "photo") }
        let currentFrame = PhotoMenuImportSource(
            id: "current-frame",
            title: "Current Frame",
            systemImage: "film",
            load: { SBJResourceContent(data: Data([0x89]), contentType: .png) }
        )
        _ = PhotoMenu(source: deferred, additionalSources: [currentFrame])
        _ = PhotoMenu(resource: resource, additionalSources: [currentFrame])
        _ = PhotoMenu(source: deferred, additionalSources: [currentFrame]) {
            Image(systemName: "photo")
        }
        _ = PhotoMenu(resource: resource, additionalSources: [currentFrame]) {
            Image(systemName: "photo")
        }
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
