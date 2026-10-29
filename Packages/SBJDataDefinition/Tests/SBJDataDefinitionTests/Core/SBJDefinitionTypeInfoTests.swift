import Testing
import SBJLocalization
@testable import SBJDataDefinition

enum AttunementTestState: String, Codable, SBJDefinitionTypeInfoProviding {
    case active
    static let definitionTypeInfo = SBJPropertyInfo(
        title: "Attunement", summary: "Shared explanation",
        details: "Type-level details", accessibilityHint: "Shared hint"
    )
}

@SBJStructure
struct TypeInfoTestOwner: Codable {
    var state: AttunementTestState = .active
    var optionalState: AttunementTestState? = nil
    var plainText: String = ""
}

@SBJPropertyInfo
extension TypeInfoTestOwner {
    static let stateInfo = SBJPropertyInfo(summary: "Property-specific explanation")
}

@Test func definitionTypeInfoMergesEachAttribute() {
    let info = TypeInfoTestOwner.propertyInfo(for: \.state)
    #expect(info?.title == "Attunement")
    #expect(info?.summary == "Property-specific explanation")
    #expect(info?.details == "Type-level details")
    #expect(info?.accessibilityHint == "Shared hint")
    #expect(TypeInfoTestOwner.propertyInfo(for: \.optionalState)?.title == "Attunement")
    #expect(TypeInfoTestOwner.propertyInfo(for: \.plainText) == nil)
}


@Test func definitionTypeInfoProvidesAllDefaultsWhenPropertyInfoIsAbsent() {
    let info = TypeInfoTestOwner.propertyInfo(for: \.optionalState)
    #expect(info?.title == "Attunement")
    #expect(info?.summary == "Shared explanation")
    #expect(info?.details == "Type-level details")
    #expect(info?.accessibilityHint == "Shared hint")
}

@Test func definitionTypeInfoResolutionPreservesExplicitAttributes() {
    let override = SBJPropertyInfo(
        title: "Specific title", details: "Specific details",
        accessibilityLabel: "Specific accessibility label"
    )
    let resolved = override.mergingDefaults(from: AttunementTestState.definitionTypeInfo)
    #expect(resolved.title == "Specific title")
    #expect(resolved.summary == "Shared explanation")
    #expect(resolved.details == "Specific details")
    #expect(resolved.accessibilityLabel == "Specific accessibility label")
    #expect(resolved.accessibilityHint == "Shared hint")
    #expect(override.summary == nil) // Resolution must not change declarations.
    #expect(SBJDefinitionTypeInfo.resolve(override, for: AttunementTestState.self)?.summary == "Shared explanation")
}

@Test func definitionTypeInfoResolutionDoesNotInventDefaultsForUnannotatedTypes() {
    let original = SBJPropertyInfo(title: "Count")
    let resolved = SBJDefinitionTypeInfo.resolve(original, for: Int.self)
    #expect(resolved?.title == "Count")
    #expect(resolved?.summary == nil)
    let absent: SBJPropertyInfo? = nil
    #expect(SBJDefinitionTypeInfo.resolve(absent, for: String.self) == nil)
}
