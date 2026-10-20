import Foundation
import XCTest
import SBJFileResources
@testable import SBJHelp

final class SBJHelpPackageTests: XCTestCase {
    func testApplicationTemplateSubstitutions() {
        var config = SBJHelpConfiguration.standard
        config.applicationSubstitutions["DISPLAY_NAME"] = "Example App"
        let asset = SBJBundledContentReference(displayName: "Welcome")
        let substitutions = SBJHelpTemplateRenderer(configuration: config).standardSubstitutions(for: asset)
        XCTAssertEqual(substitutions["TITLE"], "Welcome")
        XCTAssertEqual(substitutions["DISPLAY_NAME"], "Example App")
    }
}
