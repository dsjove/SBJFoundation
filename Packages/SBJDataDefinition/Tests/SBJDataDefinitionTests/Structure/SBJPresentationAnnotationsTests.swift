import XCTest
@testable import SBJDataDefinition

@SBJStructure
private struct PresentationFixture: Codable {
    @SBJPresentationString(.multiline, autocorrect: .disabled, capitalization: .sentences)
    @SBJPresentationDisclosure(.autoOpen)
    var notes: String = ""

    @SBJPresentationExclude
    var hidden: String = ""

    @SBJPresentationArray(title: \PresentationFixture.Entry.title)
    var entries: [Entry] = []

    struct Entry: Codable {
        var title: String = ""
    }
}

final class SBJPresentationAnnotationsTests: XCTestCase {
    func testPresentationHintsArePartOfStructuralMetadata() {
        let properties = PresentationFixture.sbjProperties
        XCTAssertEqual(properties.map(\.sourceName), ["notes", "hidden", "entries"])
        XCTAssertTrue(properties[0].hints.contains(.textStyle(.multiline)))
        XCTAssertTrue(properties[0].hints.contains(.textAutocorrection(.disabled)))
        XCTAssertTrue(properties[0].hints.contains(.textCapitalization(.sentences)))
        XCTAssertTrue(properties[0].hints.contains(.presentationDisclosure(.autoOpen)))
        XCTAssertTrue(properties[1].hints.contains(.presentationExcluded))
        XCTAssertTrue(properties[2].hints.contains(.itemTitle("title")))
    }
}

@SBJStructure
private struct ComputedPresentationFixture: Codable {
    var stored: String = "model"

    @SBJPresentationProperty
    var label: String {
        get { stored }
        set { stored = newValue }
    }
}

extension SBJPresentationAnnotationsTests {
    func testComputedPresentationPropertyDoesNotEnterStructuralSchema() {
        XCTAssertEqual(ComputedPresentationFixture.sbjProperties.map(\.sourceName), ["stored"])
        XCTAssertEqual(ComputedPresentationFixture.sbjMutableProperties.count, 1)
        let fields = ComputedPresentationFixture.sbjPresentationProperties
        XCTAssertEqual(fields.count, 1)
        XCTAssertNil(fields[0].structuralMetadata)
        var value = ComputedPresentationFixture()
        XCTAssertEqual(fields[0].value(in: value) as? String, "model")
        XCTAssertTrue(fields[0].setValue("updated", in: &value))
        XCTAssertEqual(value.stored, "updated")
    }
}
