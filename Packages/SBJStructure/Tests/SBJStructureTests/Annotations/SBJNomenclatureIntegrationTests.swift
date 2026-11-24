import Testing
import SBJLocalization
@testable import SBJStructure

enum AttunementTestState: String, Codable, SBJNomenclatureProviding {
    case active
    static let nomenclature = SBJNomenclature(
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

@SBJStructureExtension
extension TypeInfoTestOwner {
    static let stateNomenclature = SBJNomenclature(summary: "Property-specific explanation")
}

@Test func definitionTypeInfoMergesEachAttribute() {
    let info = TypeInfoTestOwner.propertyNomenclature(for: \.state)
    #expect(info?.title == "Attunement")
    #expect(info?.summary == "Property-specific explanation")
    #expect(info?.details == "Type-level details")
    #expect(info?.accessibilityHint == "Shared hint")
    #expect(TypeInfoTestOwner.propertyNomenclature(for: \.optionalState)?.title == "Attunement")
    #expect(TypeInfoTestOwner.propertyNomenclature(for: \.plainText) == nil)
}


@Test func definitionTypeInfoProvidesAllDefaultsWhenNomenclatureIsAbsent() {
    let info = TypeInfoTestOwner.propertyNomenclature(for: \.optionalState)
    #expect(info?.title == "Attunement")
    #expect(info?.summary == "Shared explanation")
    #expect(info?.details == "Type-level details")
    #expect(info?.accessibilityHint == "Shared hint")
}

@Test func definitionTypeInfoResolutionPreservesExplicitAttributes() {
    let override = SBJNomenclature(
        title: "Specific title", details: "Specific details",
        accessibilityLabel: "Specific accessibility label"
    )
    let resolved = override.mergingDefaults(from: AttunementTestState.nomenclature)
    #expect(resolved.title == "Specific title")
    #expect(resolved.summary == "Shared explanation")
    #expect(resolved.details == "Specific details")
    #expect(resolved.accessibilityLabel == "Specific accessibility label")
    #expect(resolved.accessibilityHint == "Shared hint")
    #expect(override.summary == nil) // Resolution must not change declarations.
    #expect(SBJNomenclatureResolver.resolve(override, for: AttunementTestState.self)?.summary == "Shared explanation")
}

@Test func definitionTypeInfoResolutionDoesNotInventDefaultsForUnannotatedTypes() {
    let original = SBJNomenclature(title: "Count")
    let resolved = SBJNomenclatureResolver.resolve(original, for: Int.self)
    #expect(resolved?.title == "Count")
    #expect(resolved?.summary == nil)
    let absent: SBJNomenclature? = nil
    #expect(SBJNomenclatureResolver.resolve(absent, for: String.self) == nil)
}

@Test func nomenclatureDetailsMergeWithDefaults() {
    let defaults = SBJNomenclature(details: "Default instructions")
    let explicit = SBJNomenclature(title: "Title")
    #expect(explicit.mergingDefaults(from: defaults).details != nil)
    #expect(SBJNomenclature(details: "Override").mergingDefaults(from: defaults).details != nil)
}
