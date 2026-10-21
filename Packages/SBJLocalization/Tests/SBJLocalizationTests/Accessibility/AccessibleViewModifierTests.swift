import SwiftUI
import Testing
@testable import SBJLocalization

@Suite("Accessible view modifiers")
struct AccessibleViewModifierTests {
    @MainActor
    @Test func accessibleViewModifierRetainsEstablishedSurface() {
        let item: any Accessible = AccessibleItem(
            label: "Name",
            hint: "Enter a name",
            value: "Current"
        )
        _ = Text("Name").accessibility(item)
        _ = Text("Name").accessibility(label: "Name", hint: "Hint", value: "Value")
    }
}
