#if !os(tvOS) && !os(watchOS)
import Testing
@testable import SBJStructuredEditor

struct SBJEditorHelpResourcesTests {
    @Test func coreHelpIsBundledAndReadable() {
        #expect(SBJEditorHelpResources.core.exists)
        #expect(SBJEditorHelpResources.core.stringValue()?.contains("<") == true)
    }

    @Test func searchHelpIsBundledAndReadable() {
        #expect(SBJEditorHelpResources.search.exists)
        #expect(SBJEditorHelpResources.search.stringValue()?.contains("<") == true)
    }
}
#endif
