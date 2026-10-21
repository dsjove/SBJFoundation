import Testing
@testable import SBJLocalization

@Suite("Accessible metadata")
struct AccessibleMetadataTests {
    @Test func propertyInfoUsesOriginalAccessibleProtocol() {
        let info = SBJPropertyInfo(
            summary: "Summary",
            details: "Details",
            accessibilityLabel: "Label",
            accessibilityHint: "Hint",
            accessibilityValue: "Value"
        )
        let accessible: any Accessible = info
        #expect(accessible.accessibilityLabel == "Label")
        #expect(accessible.accessibilityHint == "Hint")
        #expect(accessible.accessibilityValue == "Value")
        #expect(info.accessibility == AccessibleItem(label: "Label", hint: "Hint", value: "Value"))
        #expect(SBJPropertyInfo(summary: "Summary", details: "Details", accessibility: info.accessibility) == info)
    }

    @Test func accessibleItemRetainsOriginalInitializer() {
        let item = AccessibleItem(label: "Label", hint: "Hint", value: "Value")
        #expect(item.accessibilityLabel == "Label")
        #expect(item.accessibilityHint == "Hint")
        #expect(item.accessibilityValue == "Value")
        #expect(!item.isEmpty)
        #expect(AccessibleItem().isEmpty)
    }
}
