import XCTest
import SBJFileResources
import SBJHelp
@testable import SBJFoundation

#if !os(watchOS)
final class SBJFoundationHelpIntegrationTests: XCTestCase {
    func testEmbeddedFrameworkHelpIsExpandedInsideApplicationHelp() throws {
        let parent = SBJBundledContentReference.help("Embedding Fixture", bundle: .module)
        let source = try XCTUnwrap(SBJHelpTemplateRenderer(configuration: .foundation).renderedSource(for: parent))
        XCTAssertFalse(source.contains("UI_help\\"))
        XCTAssertTrue(source.contains("data:image/png;base64"))
        XCTAssertTrue(source.contains("style='height:1em;width:auto;vertical-align:-0.125em'"))
    }
}
#endif
