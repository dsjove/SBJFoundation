import Foundation
import Testing
import UniformTypeIdentifiers
@testable import SBJFileResources

@Suite("Deferred resource sources")
struct SBJResourceSourceTests {
    @Test @MainActor func immediateContentAvailability() async throws {
        let absent = SBJResourceSource.content(nil)
        #expect(absent.hasContent == false)
        #expect(try await absent.resolve() == nil)

        let resource = SBJResourceContent(data: Data([1, 2]), contentType: .png)
        let present = SBJResourceSource.content(resource)
        #expect(present.hasContent == true)
        #expect(try await present.resolve() == resource)
    }

    @Test @MainActor func deferredAvailabilityDoesNotTriggerLoad() async throws {
        let source = SBJResourceSource.deferred(hasContent: nil, load: { nil }, save: { _ in })
        #expect(source.hasContent == nil)
        #expect(try await source.resolve() == nil)
    }

    @Test @MainActor func knownAbsenceIsNonLoadingHint() async throws {
        let source = SBJResourceSource.deferred(hasContent: false, load: { nil }, save: { _ in })
        #expect(source.hasContent == false)
        #expect(try await source.resolve() == nil)
    }
}

@MainActor
private final class ResourceSourceTestStore {
    var value: SBJResourceContent?
}

extension SBJResourceSourceTests {
    @Test @MainActor func deferredSourceWritesAndClears() async throws {
        let store = ResourceSourceTestStore()
        let source = SBJResourceSource.deferred(
            hasContent: nil,
            load: { store.value },
            save: { store.value = $0 }
        )
        let image = SBJResourceContent(data: Data([1, 2, 3]), contentType: .png)
        try await source.save(image)
        #expect(try await source.resolve() == image)
        try await source.save(nil)
        #expect(try await source.resolve() == nil)
    }
}
