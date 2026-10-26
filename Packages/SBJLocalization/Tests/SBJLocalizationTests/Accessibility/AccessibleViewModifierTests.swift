import SwiftUI
import Testing
@testable import SBJLocalization

@Suite("Accessible view modifiers")
struct AccessibleViewModifierTests {
    @MainActor
    @Test func accessibleViewModifierAcceptsAssembledItem() {
        let item = AccessibleItem(
            label: "Name",
            hint: "Enter a name",
            value: "Current"
        )
        _ = Text("Name").accessibility(item)
        _ = Text("Name").accessibility(AccessibleItem(label: "Name"))
        _ = Text("Name").accessibility(nil as AccessibleItem?)
        _ = Text("Name").accessibility(SBJPropertyInfo(accessibilityLabel: "Name"))
        _ = Text("Name").accessibility(label: "Name", hint: "Hint", value: "Value")
    }
}
