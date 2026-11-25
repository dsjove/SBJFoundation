import Testing
@testable import SBJStructure

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
        #expect(fields.map(\.name) == ["Title", "Count", "Summary"])

        var value = MutablePropertyModel(title: "Before", count: 2)
        let title = fields[0]

        #expect(title.value(in: value) as? String == "Before")
        #expect(title.setValue("After", in: &value))
        #expect(value.title == "After")
        #expect(!title.setValue(42, in: &value))
    }

    @Test func generatedMutablePropertyCarriesStructuralMetadata() {
        let fields = MutablePropertyModel.sbjMutableProperties

        #expect(fields[0].structuralMetadata.sourceName == "title")
        #expect(fields[1].structuralMetadata.sourceName == "count")
        let summary = fields[2]
        #expect(summary.structuralMetadata.sourceName == "summary")
        #expect(summary.structuralMetadata.storage == .computed)
        #expect(summary.structuralMetadata.access == .readWrite)
        var value = MutablePropertyModel(title: "Before", count: 2)
        #expect(summary.value(in: value) as? String == "Before: 2")
        #expect(summary.setValue("After", in: &value))
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
