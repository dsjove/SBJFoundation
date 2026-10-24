import Foundation
import Testing
@testable import SBJStructuredEditor
import SBJUIVocabulary

struct SBJPhase7CoverageTests {




    @MainActor
    @Test func recipeStructuralFieldsAreProjectedForEditing() {
        let fields = SBJStructuralFieldProjection.fields(of: SBJStructureSampleModel.self)
        #expect(fields.contains { $0.editableField.structuralMetadata?.sourceName == "name" })
        #expect(fields.contains { $0.editableField.structuralMetadata?.sourceName == "ingredients" })
        #expect(fields.contains { $0.editableField.structuralMetadata?.sourceName == "cookingStages" })
    }



    @Test func hexParserCoversFormattingEmptyInputAndFailures() throws {
        #expect(try "".sbjHexData() == Data())
        #expect(try "01:23_45-67.89 AB\nCD".sbjHexData() == Data([0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD]))
        #expect(try "aa bb cc".sbjHexData() == Data([0xAA, 0xBB, 0xCC]))
        #expect(throws: SBJHexError.incompleteByte) {
            try "0".sbjHexData()
        }
        #expect(throws: SBJHexError.invalidCharacter("G")) {
            try "0G".sbjHexData()
        }
        #expect("0G".sbjHexToData() == nil)
    }

    @Test func hexFormatterHasStableEditorFriendlyOutput() {
        let value = Data([0x00, 0x01, 0xAB, 0xFF])
        #expect(value.sbjHexFormat(bytesPerRow: 2) == "00 01\nAB FF")
        #expect(value.sbjHexFormat(bytesPerRow: 0) == "00\n01\nAB\nFF")
        #expect(value.sbjHexFormat(bytesPerRow: 2, indent: "  ") == "  00 01\n  AB FF")
        #expect(Data().sbjHexFormat().isEmpty)
    }


}

extension SBJPhase7CoverageTests {
    @Test func smartURLParsingIsPermissiveAndTrimsWhitespace() {
        #expect(" https://example.com/path ".sbjURL?.absoluteString == "https://example.com/path")
        #expect("mailto:test@example.com".sbjURL?.scheme == "mailto")
        #expect("relative/path".sbjURL?.relativeString == "relative/path")
        #expect("example.com".sbjURL?.relativeString == "example.com")
    }





    @Test func smartUUIDParsingAcceptsCanonicalCompactAndBracedForms() {
        let expected = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!
        #expect("550E8400-E29B-41D4-A716-446655440000".sbjUUID == expected)
        #expect("550E8400E29B41D4A716446655440000".sbjUUID == expected)
        #expect("{550e8400-e29b-41d4-a716-446655440000}".sbjUUID == expected)
        #expect("not-a-uuid".sbjUUID == nil)
    }
}

private struct SBJUtilityCopyValue: Codable, Equatable {
    var name: String
    var count: Int
}

extension SBJPhase7CoverageTests {
    @Test func publicCodableUtilitiesSupportSnapshotsAndChangeComparison() {
        let original = SBJUtilityCopyValue(name: "one", count: 1)
        let copy = original.sbjCodableCopy()
        #expect(copy == original)
        #expect(!copy.sbjEncodedIsDifferent(from: original))

        let changed = SBJUtilityCopyValue(name: "one", count: 2)
        #expect(changed.sbjEncodedIsDifferent(from: original))
    }
}

extension SBJPhase7CoverageTests {



}
