import Foundation
import SBJDataDefinition
import Testing
import SBJLocalization
@testable import SBJFoundation

@Suite("Foundation utilities")
struct SBJFoundationUtilitiesTests {
    @Test func stringUtilities() {
        #expect("  Hello \n".trimmed == "Hello")
        #expect(" \n ".querify == nil)
        #expect("  Hello ".isEquivalent(to: "hello"))
    }

    @Test func collectionUtilities() {
        #expect([1, 2, 1, 3, 2].removingDuplicatesPreservingOrder() == [1, 2, 3])
        #expect(Set([1, 2, 1, 3, 2].removingDuplicatesUnordered()) == Set([1, 2, 3]))
        let grouped = ["a", "bb", "c"].grouped(by: \.count)
        #expect(grouped[1] == ["a", "c"])
        #expect(grouped[2] == ["bb"])
    }

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

    @Test func identifiedURLUsesGenericIdentityWrapper() {
        let value: IdentifiedURL = Identified(URL(string: "https://example.com")!)
        #expect(value.value.absoluteString == "https://example.com")
    }
    @Test func dictionaryRenamePreservesOptionalNilValue() {
        var values: [String: Int?] = [:]
        values.updateValue(nil, forKey: "old")

        #expect(values.keys.contains("old"))
        let renamed = values.sbjRenameKey("old", to: "new")
        #expect(renamed)
        #expect(!values.keys.contains("old"))
        #expect(values.keys.contains("new"))
        #expect(values["new"] != nil)
    }

    @Test func dictionaryUpdatePreservesOptionalNilEntry() {
        var values: [String: Int?] = ["key": 1]
        values.updateValue(nil, forKey: "key")

        #expect(values.keys.contains("key"))
        #expect(values["key"] != nil)
    }

}
