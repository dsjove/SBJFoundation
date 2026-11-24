import Testing
@testable import SBJStructuredReport

@Test func typeDisplayPreservesCustomModuleIdentifiers() {
    #expect(SBJDefinitionTypeDisplay.format("MySwift.Models.Widget") == "MySwift.Models.Widget")
    #expect(SBJDefinitionTypeDisplay.format("Swift.Array<MySwift.Models.Widget>") == "Array<MySwift.Models.Widget>")
}

@Test func typeDisplayFormatsNestedOptionals() {
    #expect(SBJDefinitionTypeDisplay.format("Swift.Optional<Swift.Array<Swift.Optional<Swift.Int>>>") == "Array<Int?>?")
}

@Test func typeDisplayLeavesMalformedOptionalNotationUnchanged() {
    #expect(SBJDefinitionTypeDisplay.format("Optional<Int") == "Optional<Int")
}
