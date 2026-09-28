#if !os(watchOS)
import XCTest
import UniformTypeIdentifiers
@testable import SBJFoundation

final class SBJHelpTests: XCTestCase {
    func testFilenameExtensionsUseUniformTypeIdentifiers() {
        XCTAssertEqual(UTType(filenameExtension: "html"), .html)
		if #available(macCatalyst 27.0, iOS 27.0, *) {
			XCTAssertEqual(UTType(filenameExtension: "md"), .markdown)
		}
    }

	@available(macCatalyst 27.0, iOS 27.0, *)
	func testExplicitContentTypeOverridesAssetCatalogIdentifier() {
        let resolved = SBJAssetReference.resolvedContentType(
            override: .markdown,
            assetTypeIdentifier: UTType.html.identifier
        )
        XCTAssertEqual(resolved, .markdown)
    }

    func testAssetCatalogIdentifierResolvesContentType() {
        let resolved = SBJAssetReference.resolvedContentType(
            override: nil,
            assetTypeIdentifier: UTType.html.identifier
        )
        XCTAssertEqual(resolved, .html)
    }

    func testBundleResourceNameDefaultsToSanitizedDisplayName() {
        let asset = SBJAssetReference(
            displayName: "Recipe Details",
            subdirectory: "help"
        )
        XCTAssertEqual(asset.fullName, "help/RecipeDetails")
    }

	@available(macCatalyst 27.0, iOS 27.0, *)
	func testExplicitDataAssetContentTypeOverride() {
        let asset = SBJAssetReference(displayName: "Recipe Details", dataAsset: "help/RecipeDetails", contentType: .markdown)
        XCTAssertEqual(asset.contentTypeOverride, .markdown)
    }

	@available(macCatalyst 27.0, iOS 27.0, *)
	@MainActor
    func testBuiltInPresentersAreSelectedByContentType() {
        XCTAssertNotNil(SBJHelpPresenters.builtIn(for: .html))
        XCTAssertNotNil(SBJHelpPresenters.builtIn(for: .markdown))
        XCTAssertNil(SBJHelpPresenters.builtIn(for: .json))
    }

    @MainActor
    func testHelpLinkCompilesOnCurrentPlatform() {
        _ = SBJHelpLink(asset: .structureEditorCore)
        _ = SBJHelpButton(asset: .structureEditorCore)
    }

    func testBundledStructureSearchHelpIsAvailable() {
        let asset = SBJAssetReference.structureEditorSearch
        XCTAssertTrue(asset.exists)
        XCTAssertEqual(asset.contentType, .html)
    }

    func testBundledResourceContentTypeCanComeFromExtension() {
        let asset = SBJAssetReference.help("Embedding Fixture", bundle: .module)
        XCTAssertEqual(asset.contentType, .html)
        XCTAssertTrue(asset.exists)
    }

    func testEmbeddedFrameworkHelpIsExpandedInsideApplicationHelp() throws {
        let parent = SBJAssetReference.help("Embedding Fixture", bundle: .module)
        let source = try XCTUnwrap(SBJHelpTemplateRenderer().renderedSource(for: parent))
        XCTAssertFalse(source.contains("SBJ_STRUCTURE_EDITOR_SEARCH_HELP"))
        XCTAssertFalse(source.contains("UI_help\\"))
        XCTAssertTrue(source.contains("data:image/png;base64"))
        XCTAssertTrue(source.contains("style='height:1em;width:auto;vertical-align:-0.125em'"))
    }


}
#endif
