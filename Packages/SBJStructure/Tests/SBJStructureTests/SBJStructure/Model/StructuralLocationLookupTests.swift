import Testing
@testable import SBJStructure

@SBJStructure
private struct LocationFixture: Codable {
    var name: String = ""
    var count: Int = 0
}

@SBJStructure
private struct DefinitionLocationFixture: Codable {
    let id: String
    var name: String

    init(name: String = "editable") {
        self.name = name
        self.id = "fixed"
    }
}

struct StructuralLocationLookupTests {
    @Test func completeDefinitionIncludesImmutableProperties() {
        let locations = SBJStructuralLocationLookup.definitionLocations(of: DefinitionLocationFixture.self)
        #expect(locations.count == 2)
        #expect(locations["id"]?.identity == "property:id")
        #expect(locations["name"]?.identity == "property:name")
        #expect(SBJStructuralLocationLookup.definitionLocation(sourceName: "id", in: DefinitionLocationFixture.self) == locations["id"])
        #expect(SBJStructuralLocationLookup.definitionLocation(sourceName: "missing", in: DefinitionLocationFixture.self) == nil)
        #expect(DefinitionLocationFixture.sbjSwiftWritablePropertyNames == ["name"])
        let writable = SBJStructuralLocationLookup.locations(of: DefinitionLocationFixture.self)
        #expect(writable["id"] == nil)
        #expect(writable["name"] != nil)
    }

    @Test func identityAndPositionMatchTheStructuralSchema() {
        let schema = SBJStructuralTraversal.schema(of: LocationFixture.self)
        let lookup = SBJStructuralLocationLookup.locations(of: LocationFixture.self)
        #expect(lookup.count == schema.count)
        for property in schema {
            let found = lookup[property.sourceName]
            #expect(found?.identity == property.identityComponent)
            #expect(found?.location == property.locationComponent)
            #expect(SBJStructuralLocationLookup.resolve(sourceName: property.sourceName, in: LocationFixture.self) == found)
        }
        #expect(SBJStructuralLocationLookup.resolve(sourceName: "unknown", in: LocationFixture.self) == nil)
    }
}
