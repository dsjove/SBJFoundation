import Testing
@testable import SBJLocalization

@Suite("Accessible metadata")
struct AccessibleMetadataTests {
    @Test func propertyInfoOnlyHoldsDeclarationMetadata() {
        let info = SBJNomenclature(
            summary: "Summary", details: "Details",
            accessibilityLabel: "Label", accessibilityHint: "Hint"
        )
        #expect(info.accessibilityLabel == "Label")
        #expect(info.accessibilityHint == "Hint")
        #expect(info.accessibility == AccessibleItem(label: "Label", hint: "Hint"))
    }

    @Test func propertyInfoUsesTitleAndSummaryAsAccessibilityFallbacks() {
        let info = SBJNomenclature(title: "Attunement", summary: "Current attunement state", details: "Long explanatory prose")
        #expect(info.accessibility == AccessibleItem(label: "Attunement", hint: "Current attunement state"))
        #expect(info.accessibilityLabel == nil)
        #expect(info.accessibilityHint == nil)
    }

    @Test func explicitAccessibilityTakesPrecedenceIndependently() {
        let labelOverride = SBJNomenclature(title: "Attunement", summary: "Summary", accessibilityLabel: "Magical state")
        #expect(labelOverride.accessibility == AccessibleItem(label: "Magical state", hint: "Summary"))
        let hintOverride = SBJNomenclature(title: "Attunement", summary: "Summary", accessibilityHint: "Choose one")
        #expect(hintOverride.accessibility == AccessibleItem(label: "Attunement", hint: "Choose one"))
    }

    @Test func detailsAreSeparateFromAccessibilitySemantics() {
        let nomenclature = SBJNomenclature(details: "Instructions")
        #expect(nomenclature.details != nil)
        #expect(nomenclature.accessibility.isEmpty)
    }

    @Test func detailsAreNotUsedAsFallbackHints() {
        let detailsOnly = SBJNomenclature(details: "Long description")
        #expect(detailsOnly.accessibility.isEmpty)
        #expect(SBJNomenclature().accessibility.isEmpty)
    }

    @Test func textPresentableBridgesRuntimeAccessibility() {
        struct Word: SBJTextPresentable {
            let presentedValue = "Readable value"
        }
        #expect(Word().accessibilityValue == nil)
        #expect(Word().presentedValue == "Readable value")
    }

    @Test func accessibleItemStoresAssembledSemantics() {
        let item = AccessibleItem(label: "Label", hint: "Hint", value: "Value")
        #expect(item.accessibilityLabel == "Label")
        #expect(item.accessibilityHint == "Hint")
        #expect(item.accessibilityValue == "Value")
        #expect(!item.isEmpty)
        #expect(AccessibleItem().isEmpty)
    }

    @Test func symbolsAndAccessibilityAreIndependent() {
        // Symbols describe visual assets; accessible semantics live in AccessibleItem.
        let symbol = SBJSymbol.system("star")
        let accessibility = AccessibleItem(label: "Favorite", hint: "Marks this item")
        #expect(symbol == .system("star"))
        #expect(accessibility == AccessibleItem(label: "Favorite", hint: "Marks this item"))
        #expect(!accessibility.isEmpty)
    }

    @Test func propertyInfoRetainsDocumentationAndSymbol() {
        let info = SBJNomenclature(
            title: "Name", summary: "Person's name", details: "Full legal name",
            symbol: .system("person"), accessibilityLabel: "Legal name"
        )
        #expect(info.title == "Name")
        #expect(info.summary == "Person's name")
        #expect(info.details == "Full legal name")
        #expect(info.symbol == .system("person"))
        #expect(info.accessibility == AccessibleItem(label: "Legal name", hint: "Person's name"))
    }

    @Test func textPresentableDefaultsAndCustomValues() {
        struct Word: SBJTextPresentable {
            let presentedValue = "Two Words"
        }
        struct Spoken: SBJTextPresentable {
            let presentedValue = "2024"
            let accessibilityValue: String? = "Twenty twenty-four"
        }
        #expect(Word().abbreviation == "Two Words")
        #expect(Word().multiLineDescription == "Two\nWords")
        #expect(Spoken().accessibilityValue == "Twenty twenty-four")
        #expect(Spoken().presentedValue == "2024")
    }

    @Test func rawRepresentablePresentationUsesReadableName() {
        enum Choice: String, SBJTextPresentable {
            case veryLongName
        }
        #expect(Choice.veryLongName.presentedValue == "Very Long Name")
    }
}
