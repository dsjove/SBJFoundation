import Testing
import SBJLocalization
@testable import SBJDataDefinition

@Suite("Structured accessibility composition")
struct AccessibilityItemAssemblyTests {
    @Test func runtimeTextPresentationIsOptional() {
        let plain = 42
        #expect((plain as? any SBJTextPresentable) == nil)
        let presenting: any SBJTextPresentable = TestValue()
        #expect(presenting.accessibilityValue == "test")
        #expect(DefaultValue().accessibilityValue == nil)
    }

    private struct TestValue: SBJTextPresentable {
        var presentedValue: String { "display" }
        var accessibilityValue: String? { "test" }
    }

    private struct DefaultValue: SBJTextPresentable {
        var presentedValue: String { "display" }
    }
}
