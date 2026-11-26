import XCTest
@testable import SBJStructure

@SBJStructure
private struct PresentationFixture: Codable {
    @SBJStringPresentation(.multiline, autocorrect: .disabled, capitalization: .sentences)
    @SBJFieldPresentation(autoExpand: true)
    var notes: String = ""

    @SBJFieldPresentation(exclude: true)
    var hidden: String = ""

    @SBJArray(elementName: \PresentationFixture.Entry.title)
    @SBJFieldPresentation()
    @SBJFieldPresentation()
    var entries: [Entry] = []

    @SBJDictionaryPresentation(
        key: SBJFieldPresentationValue(),
        value: SBJFieldPresentationValue()
    )
    var settings: [String: String] = [:]

    struct Entry: Codable {
        var title: String = ""
    }
}

final class SBJPresentationAnnotationsTests: XCTestCase {
    func testPresentationHintsArePartOfStructuralMetadata() {
        let properties = PresentationFixture.sbjProperties
        XCTAssertEqual(properties.map(\.sourceName), ["notes", "hidden", "entries", "settings"])
        XCTAssertTrue(properties[0].hints.contains(.stringPresentation(SBJStringPresentationValue(style: .multiline, autocorrect: .disabled, capitalization: .sentences))))
        XCTAssertEqual(properties[0].displayName, "Notes")
        XCTAssertTrue(properties[0].hints.contains(.fieldPresentation(SBJFieldPresentationValue(autoExpand: true))))
        XCTAssertTrue(properties[1].hints.contains(.fieldPresentation(SBJFieldPresentationValue(exclude: true))))
        XCTAssertTrue(properties[2].hints.contains(.elementName(\PresentationFixture.Entry.title)))
        XCTAssertTrue(properties[2].hints.contains(.fieldPresentation(SBJFieldPresentationValue())))
        XCTAssertTrue(properties[2].hints.contains(.elementFieldPresentation(SBJFieldPresentationValue())))
        XCTAssertTrue(properties[3].hints.contains(.dictionaryPresentation(
            SBJDictionaryPresentationValue(
                key: SBJFieldPresentationValue(),
                value: SBJFieldPresentationValue()
            )
        )))
    }
}

@SBJStructure
private struct ComputedPresentationFixture: Codable {
    var stored: String = "model"

    @SBJFieldPresentation()
    var label: String {
        get { stored }
        set { stored = newValue }
    }
}

extension SBJPresentationAnnotationsTests {
    func testComputedPresentationPropertyUsesCanonicalSchema() {
        XCTAssertEqual(ComputedPresentationFixture.sbjProperties.map(\.sourceName), ["stored", "label"])
        XCTAssertEqual(ComputedPresentationFixture.sbjMutableProperties.count, 2)
        let fields = ComputedPresentationFixture.sbjMutableProperties.filter { $0.structuralMetadata.storage == .computed }
        XCTAssertEqual(fields.count, 1)
        XCTAssertEqual(fields[0].structuralMetadata.sourceName, "label")
        var value = ComputedPresentationFixture()
        XCTAssertEqual(fields[0].value(in: value) as? String, "model")
        XCTAssertTrue(fields[0].setValue("updated", in: &value))
        XCTAssertEqual(value.stored, "updated")
    }
}


@SBJStructure
private struct CollectionControlConfigurationFixture: Codable {
    @SBJArrayPresentation(insertable: false, removable: false, reorderable: false)
    var ordered: [String] = []

    @SBJSetPresentation(insertable: false, removable: false)
    var members: Set<String> = []

    @SBJDictionaryPresentation(insertable: false, removable: false)
    var mapping: [String: String] = [:]
}

extension SBJPresentationAnnotationsTests {
    func testCollectionEditingPoliciesArePresentationMetadata() {
        let properties = CollectionControlConfigurationFixture.sbjProperties
        XCTAssertEqual(properties.map(\.sourceName), ["ordered", "members", "mapping"])
        XCTAssertTrue(properties[0].hints.contains(.arrayPresentation(
            SBJArrayPresentationValue(insertable: false, removable: false, reorderable: false)
        )))
        XCTAssertTrue(properties[1].hints.contains(.setPresentation(
            SBJSetPresentationValue(insertable: false, removable: false)
        )))
        XCTAssertTrue(properties[2].hints.contains(.dictionaryPresentation(
            SBJDictionaryPresentationValue(insertable: false, removable: false)
        )))
        XCTAssertTrue(properties.allSatisfy { $0.constraints.isEmpty })
    }
}
