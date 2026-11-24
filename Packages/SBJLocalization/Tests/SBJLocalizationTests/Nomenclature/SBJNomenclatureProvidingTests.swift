import Testing
@testable import SBJLocalization

private struct SampleMeaning: SBJNomenclatureProviding {
    static let nomenclature = SBJNomenclature(
        title: "Default title", summary: "Default summary", aliases: ["default"]
    )
}

struct SBJNomenclatureProvidingTests {
    @Test func typeDefaultsApplyWhenPropertyTerminologyIsMissing() {
        let result = SBJNomenclatureResolver.resolve(nil, for: SampleMeaning.self)
        #expect(result?.title == "Default title")
        #expect(result?.summary == "Default summary")
    }

    @Test func explicitMeaningOverridesOnlyItsOwnFields() {
        let result = SBJNomenclatureResolver.resolve(
            SBJNomenclature(title: "Specific title"), for: SampleMeaning.self
        )
        #expect(result?.title == "Specific title")
        #expect(result?.summary == "Default summary")
        #expect(result?.aliases == ["default"])
    }

    @Test func optionalTypesInheritMeaningAndUnrelatedTypesDoNotInventMeaning() {
        #expect(SBJNomenclatureResolver.resolve(nil, for: SampleMeaning?.self)?.title == "Default title")
        #expect(SBJNomenclatureResolver.resolve(nil, for: Int.self) == nil)
    }
}
