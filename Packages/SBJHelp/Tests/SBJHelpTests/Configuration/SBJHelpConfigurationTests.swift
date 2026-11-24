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

    func testNomenclatureSetRegistersStableNamespacedIDs() {
        var configuration = SBJHelpConfiguration.standard
        configuration.addNomenclatureSet(TestNomenclature.self)
        XCTAssertNotNil(configuration.nomenclatures["actions.test"])
        XCTAssertEqual(configuration.nomenclatures["actions.test"]?.symbol, .system("star"))
        XCTAssertNotNil(configuration.nomenclatures["add"])
    }

    func testNomenclatureTagRendersCanonicalDetailsAndEscapesHTML() {
        var configuration = SBJHelpConfiguration.standard
        configuration.nomenclatures["test.action"] = .init(
            title: "Test & Review", details: "Uses <one> canonical description"
        )
        let html = SBJHelpTemplateRenderer(configuration: configuration)
            .replacingNomenclatureEntries(in: "NOM_test.action\\")
        XCTAssertTrue(html.contains("Test &amp; Review"))
        XCTAssertTrue(html.contains("Uses &lt;one&gt; canonical description"))
        XCTAssertTrue(html.contains("class=\"sbj-nomenclature\""))
        XCTAssertFalse(html.contains("NOM_test.action"))
    }

    func testUnknownNomenclatureTokenRemainsVisible() {
        let renderer = SBJHelpTemplateRenderer(configuration: .standard)
        XCTAssertEqual(renderer.replacingNomenclatureEntries(in: "NOM_unknown.action\\"), "NOM_unknown.action\\")
    }

    func testNomenclatureEscapesAttributesAndDetails() {
        var configuration = SBJHelpConfiguration.standard
        configuration.nomenclatures["test.attribute"] = .init(
            title: "A \"quoted\" & <named> action",
            details: "Use <item> & inspect \"details\"."
        )
        let html = SBJHelpTemplateRenderer(configuration: configuration)
            .replacingNomenclatureEntries(in: "NOM_test.attribute\\")
        XCTAssertTrue(html.contains("A &quot;quoted&quot; &amp; &lt;named&gt; action"))
        XCTAssertTrue(html.contains("Use &lt;item&gt; &amp; inspect &quot;details&quot;."))
        XCTAssertTrue(html.contains("data-nomenclature=\"test.attribute\""))
    }

    func testStandardHelpUsesBundledSharedStyleSheet() {
        let configuration = SBJHelpConfiguration.standard
        XCTAssertNil(configuration.styleSheetAsset)
        let css = SBJHelpTemplateRenderer(configuration: configuration)
            .standardSubstitutions(for: .init(displayName: "Help"))["STYLE_SHEET"] ?? ""
        XCTAssertTrue(css.contains(".sbj-nomenclature"))
        XCTAssertTrue(css.contains(".help-icon"))
        XCTAssertTrue(css.contains(".tip"))
    }

    func testInitializerRespectsExplicitIconOverride() {
        let configuration = SBJHelpConfiguration(applicationSubstitutions: ["ICON": "custom-icon"])
        XCTAssertEqual(configuration.applicationSubstitutions["ICON"], "custom-icon")
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

private enum TestNomenclature: SBJNomenclatureSet {
    static let all: [String: SBJNomenclature] = [
        "actions.test": .init(title: "Test", details: "Does a test action", symbol: .system("star")),
    ]
}
