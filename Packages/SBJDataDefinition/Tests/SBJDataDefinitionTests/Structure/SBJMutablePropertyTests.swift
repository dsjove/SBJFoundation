import Testing
@testable import SBJDataDefinition

@SBJStructure
private struct MutablePropertyModel: Codable {
    var title: String
    var count: Int

    @SBJFieldPresentation()
    var summary: String {
        get { "\(title): \(count)" }
        set { title = newValue }
    }
}

struct SBJMutablePropertyTests {
    @Test func generatedMutablePropertiesAreUIIndependentAndWritable() {
        let fields = MutablePropertyModel.sbjMutableProperties
        #expect(fields.map(\.name) == ["Title", "Count"])
        #expect(MutablePropertyModel.sbjPresentationProperties.map(\.name) == ["Summary"])

        var value = MutablePropertyModel(title: "Before", count: 2)
        let title = fields[0]

        #expect(title.value(in: value) as? String == "Before")
        #expect(title.setValue("After", in: &value))
        #expect(value.title == "After")
        #expect(!title.setValue(42, in: &value))
    }

    @Test func generatedMutablePropertyCarriesStructuralMetadata() {
        let fields = MutablePropertyModel.sbjMutableProperties

        #expect(fields[0].structuralMetadata?.sourceName == "title")
        #expect(fields[1].structuralMetadata?.sourceName == "count")
        let presentationFields = MutablePropertyModel.sbjPresentationProperties
        #expect(presentationFields.count == 1)
        #expect(presentationFields[0].structuralMetadata == nil)
        #expect(fields[0].participatesInStructuralValidation)
        #expect(!presentationFields[0].participatesInStructuralValidation)

        var value = MutablePropertyModel(title: "Before", count: 2)
        #expect(presentationFields[0].value(in: value) as? String == "Before: 2")
        #expect(presentationFields[0].setValue("After", in: &value))
        #expect(value.title == "After")
    }

    @Test func generatedMutablePropertyProvidesSharedSearchAndChangeSemantics() {
        let field = MutablePropertyModel.sbjMutableProperties[0]
        let original = MutablePropertyModel(title: "Original", count: 2)
        let changed = MutablePropertyModel(title: "Changed", count: 2)

        #expect(field.matchesSearch(in: changed, query: "changed"))
        #expect(!field.hasChanged(in: original, from: original))
        #expect(field.hasChanged(in: changed, from: original))
    }
}
