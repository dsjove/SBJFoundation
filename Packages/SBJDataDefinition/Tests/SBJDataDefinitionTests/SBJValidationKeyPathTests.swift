import Testing
import SBJDataDefinition
@testable import SBJDataDefinition

private struct ValidationPathFixture {
    var array: [String] = []
    var dictionary: [String: Int] = [:]
    var set: Set<String> = []
    var unrelated: Int = 0
}

struct SBJValidationKeyPathTests {
    @Test func propertyMembershipUsesTheOriginalSwiftKeyPath() {
        let path = SBJValidationKeyPath(\ValidationPathFixture.array)

        #expect(path.contains(property: \ValidationPathFixture.array))
        #expect(!path.contains(property: \ValidationPathFixture.unrelated))
        #expect(path.description == "Array")
        #expect(path.debugDescription.contains("ValidationPathFixture.array"))
    }

    @Test func collectionLocationsHavePresentationAndStructuralForms() {
        let root = SBJValidationKeyPath(\ValidationPathFixture.self)
        let arrayPath = root.appending(\ValidationPathFixture.array).appending(index: 2)
        let dictionaryPath = root.appending(\ValidationPathFixture.dictionary).appending(key: "strength")
        let setPath = root.appending(\ValidationPathFixture.set).appending(element: "member")

        #expect(arrayPath.description == "Array › [2]")
        #expect(dictionaryPath.description == "Dictionary › strength")
        #expect(setPath.description == "Set › member")

        #expect(arrayPath.debugDescription.hasSuffix("[2]"))
        #expect(dictionaryPath.debugDescription.hasSuffix("[\"strength\"]"))
        #expect(setPath.debugDescription.hasSuffix("{member}"))
    }

    @Test func collectionTitlesOverrideOnlyPresentationLocation() {
        let root = SBJValidationKeyPath(\ValidationPathFixture.self)
        let arrayPath = root.appending(\ValidationPathFixture.array).appending(index: 2, title: "Strength")
        let setPath = root.appending(\ValidationPathFixture.set).appending(element: "member", title: "Dexterity")

        #expect(arrayPath.description == "Array › Strength")
        #expect(setPath.description == "Set › Dexterity")
        #expect(arrayPath.debugDescription.hasSuffix("[2]"))
        #expect(setPath.debugDescription.hasSuffix("{member}"))
    }
}
