import UniformTypeIdentifiers
import XCTest
import SBJFileResources
@testable import SBJHelp

#if !os(watchOS)

final class SBJHelpTests: XCTestCase {
    func testEmbeddedHelpExpandsImageDataUsingStandardConfiguration() throws {
        let reference = SBJBundledContentReference.help("Embedding Fixture", bundle: .module)
        let source = try XCTUnwrap(SBJHelpTemplateRenderer(configuration: .standard).renderedSource(for: reference))
        XCTAssertTrue(source.contains("data:image/png;base64"))
    }

    func testFilenameExtensionsUseUniformTypeIdentifiers() {
        XCTAssertEqual(UTType(filenameExtension: "html"), .html)
		if #available(macCatalyst 27.0, iOS 27.0, *) {
			XCTAssertEqual(UTType(filenameExtension: "md"), .markdown)
		}
    }

	@available(macCatalyst 27.0, iOS 27.0, *)
	func testExplicitContentTypeOverridesAssetCatalogIdentifier() {
        let resolved = SBJBundledContentReference.resolvedContentType(
            override: .markdown,
            assetTypeIdentifier: UTType.html.identifier
        )
        XCTAssertEqual(resolved, .markdown)
    }

    func testAssetCatalogIdentifierResolvesContentType() {
        let resolved = SBJBundledContentReference.resolvedContentType(
            override: nil,
            assetTypeIdentifier: UTType.html.identifier
        )
        XCTAssertEqual(resolved, .html)
    }

    func testBundleResourceNameDefaultsToSanitizedDisplayName() {
        let asset = SBJBundledContentReference(
            displayName: "Recipe Details",
            subdirectory: "help"
        )
        XCTAssertEqual(asset.fullName, "help/RecipeDetails")
    }

	@available(macCatalyst 27.0, iOS 27.0, *)
	func testExplicitDataAssetContentTypeOverride() {
        let asset = SBJBundledContentReference(displayName: "Recipe Details", dataAsset: "help/RecipeDetails", contentType: .markdown)
        XCTAssertEqual(asset.contentTypeOverride, .markdown)
    }

	@available(macCatalyst 27.0, iOS 27.0, *)
	@MainActor
    func testBuiltInPresentersAreSelectedByContentType() {
        XCTAssertNotNil(SBJHelpPresenters.builtIn(for: .html))
        XCTAssertNotNil(SBJHelpPresenters.builtIn(for: .markdown))
        XCTAssertNil(SBJHelpPresenters.builtIn(for: .json))
    }

    func testBundledResourceContentTypeCanComeFromExtension() {
        let asset = SBJBundledContentReference.help("Embedding Fixture", bundle: .module)
        XCTAssertEqual(asset.contentType, .html)
        XCTAssertTrue(asset.exists)
    }


}
#endif
