import SBJUIVocabulary
import Foundation
import SBJDataDefinition
import Testing
@testable import SBJFoundation

@Suite("Accessibility and localization regression contract")
struct SBJAccessibilityLocalizationRegressionTests {
    @Test func spokenFieldStatePreservesEveryStructuralCue() {
        #expect(SBJEditorAccessibilitySemantics.spokenLabel(
            label: "Servings", isChanged: false, hasContent: true, isInvalid: false
        ) == "Servings")

        #expect(SBJEditorAccessibilitySemantics.spokenLabel(
            label: "Servings", isChanged: true, hasContent: true, isInvalid: false
        ) == "Servings, changed")

        #expect(SBJEditorAccessibilitySemantics.spokenLabel(
            label: "Notes", isChanged: false, hasContent: false, isInvalid: false
        ) == "Notes, no content")

        #expect(SBJEditorAccessibilitySemantics.spokenLabel(
            label: "Servings", isChanged: true, hasContent: false, isInvalid: true
        ) == "Servings, changed, no content, invalid")
    }

    @Test func itemIdentitySurvivesPositionChange() {
        let parent = SBJEditTraversalContext.root.descended(property: "Ingredients")
        let before = parent.descended(stableIdentifier: "ingredient-42", index: 0)
        let after = parent.descended(stableIdentifier: "ingredient-42", index: 4)

        #expect(before.itemIdentifier == after.itemIdentifier)
        #expect(before.indexPath != after.indexPath)
        #expect(before.treeLevel == after.treeLevel)
    }

    @Test func distinctItemsNeverShareIdentityAtSamePosition() {
        let parent = SBJEditTraversalContext.root.descended(property: "Ingredients")
        let first = parent.descended(stableIdentifier: "ingredient-1", index: 0)
        let replacement = parent.descended(stableIdentifier: "ingredient-2", index: 0)

        #expect(first.itemIdentifier != replacement.itemIdentifier)
        #expect(first.indexPath == replacement.indexPath)
    }

    @Test func humanNumbersFollowLocaleRatherThanStorageRepresentation() {
        let value = 12_345.5
        let us = value.formatted(.number.locale(Locale(identifier: "en_US")))
        let german = value.formatted(.number.locale(Locale(identifier: "de_DE")))
        let french = value.formatted(.number.locale(Locale(identifier: "fr_FR")))

        #expect(us != german)
        #expect(us != french)
        #expect(german.contains(","))
        #expect(us.contains("."))
    }

    @Test func humanDatesFollowLocale() {
        let date = Date(timeIntervalSince1970: 1_725_321_600) // stable instant; exact day is not the assertion
        let us = date.formatted(Date.FormatStyle(date: .numeric, time: .omitted).locale(Locale(identifier: "en_US")))
        let german = date.formatted(Date.FormatStyle(date: .numeric, time: .omitted).locale(Locale(identifier: "de_DE")))

        #expect(us != german)
    }

    @Test func constrainedNumericSizingStaysOrderedAcrossLocales() {
        for localeID in ["en_US", "de_DE", "fr_FR", "ar_SA"] {
            let sizing = SBJNumericFieldSizing.integer(range: -12_345...98_765, locale: Locale(identifier: localeID))
            #expect(sizing.minimum <= sizing.ideal)
            #expect(sizing.ideal <= sizing.maximum)
            #expect(sizing.maximum <= 176)
        }
    }

    @Test func technicalRepresentationsRemainLocaleInvariant() {
        let uuid = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!
        #expect(uuid.uuidString == "550E8400-E29B-41D4-A716-446655440000")

        let data = Data([0x00, 0x10, 0xAB, 0xFF])
        #expect(data.sbjHexFormat() == "00 10 AB FF")
    }
}
