import Testing
@testable import SBJLocalization

private enum ExampleNomenclature: SBJNomenclatureSet {
    static let all: [String: SBJNomenclature] = [
        "editor.insert-item": .init(title: "Insert"),
        "image.choosePhotos": .init(title: "Photos"),
        "status": .init(title: "Status")
    ]
}

struct SBJNomenclatureSetDynamicMemberTests {
    @Test func dottedAndHyphenatedIdentifiersResolveAsProperties() {
        #expect(ExampleNomenclature.editorInsertItem == ExampleNomenclature.all["editor.insert-item"])
        #expect(ExampleNomenclature.imageChoosePhotos == ExampleNomenclature.all["image.choosePhotos"])
        #expect(ExampleNomenclature.status == ExampleNomenclature.all["status"])
    }
}
