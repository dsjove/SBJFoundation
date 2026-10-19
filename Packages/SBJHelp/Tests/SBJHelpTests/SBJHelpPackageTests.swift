import Foundation
import XCTest
import SBJFileResources
@testable import SBJHelp

final class SBJHelpPackageTests: XCTestCase {
    func testLiteralReplacements() {
        XCTAssertEqual("a-b".replacingOccurrences(using: ["-": "_"]), "a_b")
    }

    func testApplicationTemplateSubstitutions() {
        var config = SBJHelpConfiguration.standard
        config.applicationSubstitutions["DISPLAY_NAME"] = "Example App"
        let asset = SBJBundledContentReference(displayName: "Welcome")
        let substitutions = SBJHelpTemplateRenderer(configuration: config).standardSubstitutions(for: asset)
        XCTAssertEqual(substitutions["TITLE"], "Welcome")
        XCTAssertEqual(substitutions["DISPLAY_NAME"], "Example App")
    }
}
