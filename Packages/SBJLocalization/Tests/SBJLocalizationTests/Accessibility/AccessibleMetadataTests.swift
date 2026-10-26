import Testing
@testable import SBJLocalization

@Suite("Accessible metadata")
struct AccessibleMetadataTests {
    @Test func propertyInfoOnlyHoldsDeclarationMetadata() {
        let info = SBJPropertyInfo(
            summary: "Summary", details: "Details",
            accessibilityLabel: "Label", accessibilityHint: "Hint"
        )
        #expect(info.accessibilityLabel == "Label")
        #expect(info.accessibilityHint == "Hint")
        #expect(info.accessibility == AccessibleItem(label: "Label", hint: "Hint"))
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

    @Test func symbolItemProvidesAssembledAccessibility() {
        let decorative = AccessibleSymbolItem(symbol: .system("star"), label: "Favorite")
        #expect(!decorative.labeled)

        #expect(decorative.accessibility.isEmpty)
        let labeled = AccessibleSymbolItem(symbol: .system("star"), labeled: true, label: "Favorite")
        #expect(labeled.accessibility == AccessibleItem(label: "Favorite"))
        #expect(labeled.labeled)
    }
}
