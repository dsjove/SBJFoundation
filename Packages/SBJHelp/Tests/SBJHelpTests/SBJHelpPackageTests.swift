import Foundation
import XCTest
import SBJLocalization
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

extension SBJHelpPackageTests {
    func testSymbolSetMergingKeepsDefaultsAndAllowsOverrides() {
        var configuration = SBJHelpConfiguration.standard
        configuration.addSymbolSet(TestSymbology.self)
        XCTAssertEqual(configuration.semanticImages["customAction"], .system("star"))
        XCTAssertEqual(configuration.semanticImages["add"], .system("plus"))
        XCTAssertEqual(configuration.semanticImages["help"], SBJHelpSymbology.help)
    }

    func testInitializerPreservesSuppliedApplicationSubstitutions() {
        let configuration = SBJHelpConfiguration(applicationSubstitutions: [
            "COMPANY_NAME": "Custom Publisher",
            "CUSTOM": "Custom Value",
        ])
        XCTAssertEqual(configuration.applicationSubstitutions["COMPANY_NAME"], "Custom Publisher")
        XCTAssertEqual(configuration.applicationSubstitutions["CUSTOM"], "Custom Value")
    }
}

private enum TestSymbology: SBJSymbolSet {
    static let all: [String: SBJSymbol] = [
        "customAction": .system("star"),
        "add": .system("plus"),
    ]
}
