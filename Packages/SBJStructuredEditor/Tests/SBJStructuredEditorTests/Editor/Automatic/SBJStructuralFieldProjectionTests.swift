import Foundation
import Testing
import SBJStructure
#if canImport(SwiftUI)
import SwiftUI
#endif
@testable import SBJStructuredEditor

@SBJStructure
private struct StructuralProjectionFixture {
    var first: String = ""
    var count: Int = 0
    let identifier: String

    init(first: String = "", count: Int = 0, identifier: String = "immutable") {
        self.first = first
        self.count = count
        self.identifier = identifier
    }
}

struct SBJStructuralFieldProjectionTests {
    @Test @MainActor
    func structuralFieldsRetainSourceNamesAndTypedKeyPaths() {
        let fields = SBJStructuralFieldProjection.fields(of: StructuralProjectionFixture.self, showsReadOnlyProperties: true)
        #expect(fields.map(\.name) == ["First", "Count", "Identifier"])
        #expect(fields.map { $0.metadata.sourceName } == ["first", "count", "identifier"])
        #expect(ObjectIdentifier(fields[0].metadata.valueType) == ObjectIdentifier(String.self))
        #expect(ObjectIdentifier(fields[1].metadata.valueType) == ObjectIdentifier(Int.self))
        let model = StructuralProjectionFixture()
        #expect(fields[0].metadata.value(in: model) as? String == "")
        #expect(fields[1].metadata.value(in: model) as? Int == 0)
        #expect(fields[2].metadata.access == .readOnly)
        #expect(fields[2].metadata.mutableProperty() == nil)
    }
}

@SBJStructure
private struct StructuralChildFixture: Codable {
    var caption: String = "nested"
}

@SBJStructure
private struct StructuralParentFixture: Codable {
    var child: StructuralChildFixture = .init()
    var children: [StructuralChildFixture] = [.init()]
}

extension SBJStructuralFieldProjectionTests {
    @Test @MainActor
    func structuralOnlyObjectIsTraversableAndEditable() {
        let root = StructuralParentFixture()
        let fields = SBJStructuralFieldProjection.fields(of: StructuralParentFixture.self)
        #expect(fields.map(\.name) == ["Child", "Children"])
        let nodes = StructuralParentFixture._sbjStructuralTraversalNodes(value: root, context: .root)
        #expect(nodes.count == 2)
        #expect(StructuralChildFixture._sbjStructuralFieldCount() == 1)
        #expect(StructuralParentFixture._sbjStructuralCollectIssues(value: root, path: [], registry: .init()).isEmpty)
    }
}

#if canImport(SwiftUI) && !os(tvOS) && !os(watchOS)
extension SBJStructuralFieldProjectionTests {
    @Test @MainActor
    func bothPublicRootEditorNamesAcceptStructureOnlyModels() {
        let binding = Binding.constant(StructuralProjectionFixture())
        let presentation = SBJEditorPresentationModel()
        _ = SBJEditorView(value: binding, presentationModel: presentation)
        _ = SBJStructuralEditorView(value: binding, presentationModel: presentation)
    }

    @Test @MainActor
    func structuralOnlyFieldConstructsModelAwareEditor() {
        let model = StructuralProjectionFixture()
        _ = SBJEditField(root: .constant(model), keyPath: \.first)
        let descriptor = SBJStructuralFieldProjection.fields(of: StructuralProjectionFixture.self, showsReadOnlyProperties: true)[0]
        #expect(ObjectIdentifier(descriptor.metadata.valueType) == ObjectIdentifier(String.self))
    }
}
#endif

@SBJStructure
private struct MixedEditorLocationFixture: Codable {
    var userName: String = ""
    var count: Int = 0
}

extension SBJStructuralFieldProjectionTests {
    @Test @MainActor
    func editableAndStructuralLocationsAgree() {
        let fields = SBJStructuralFieldProjection.fields(of: MixedEditorLocationFixture.self)
        let locations = SBJEditorStructuralLocations.resolve(fields, of: MixedEditorLocationFixture.self)
        let schema = SBJStructuralTraversal.schema(of: MixedEditorLocationFixture.self)
        #expect(locations.map(\.identity) == schema.map(\.identityComponent))
        #expect(locations.map(\.location) == schema.map(\.locationComponent))
    }

    @Test @MainActor
    func projectedStoredFieldsRetainStructuralIdentity() {
        let fields = SBJStructuralFieldProjection.fields(of: StructuralProjectionFixture.self, showsReadOnlyProperties: true)
        let locations = SBJEditorStructuralLocations.resolve(fields, of: StructuralProjectionFixture.self)
        let schema = SBJStructuralTraversal.definition(of: StructuralProjectionFixture.self)
        #expect(locations.map(\.identity) == schema.map(\.identityComponent))
        #expect(locations.map(\.location) == schema.map(\.locationComponent))
    }


}

@SBJStructure
private struct PresentationProjectionFixture: Codable {
    @SBJFieldPresentation(autoExpand: true)
    var child: StructuralChildFixture = .init()
    @SBJFieldPresentation(exclude: true)
    var internalNote: String = "not an editor field"
    @SBJStringPresentation(.multiline)
    var notes: String = ""
}

extension SBJStructuralFieldProjectionTests {
    @Test @MainActor
    func structuralProjectionHonorsPresentationAnnotations() {
        let fields = SBJStructuralFieldProjection.fields(of: PresentationProjectionFixture.self)
        #expect(fields.map(\.name) == ["Child", "Notes"])
        #expect(fields[0].traversalDisclosureMode == .autoOpen)
        #expect(fields[1].traversalDisclosureMode == .closed)
        #expect(PresentationProjectionFixture.sbjProperties.contains { $0.sourceName == "internalNote" })
        #expect(fields[1].metadata.hints.contains {
            if case .stringPresentation(let value) = $0 { return value.style == .multiline }
            return false
        } == true)
    }
}

@SBJStructure
private struct ComputedProjectionFixture: Codable {
    var stored: String = "first"

    @SBJFieldPresentation()
    var computed: String {
        get { stored }
        set { stored = newValue }
    }
}

extension SBJStructuralFieldProjectionTests {
    @Test @MainActor
    func computedWritableFieldsShareSchema() {
        let fields = SBJStructuralFieldProjection.fields(of: ComputedProjectionFixture.self)
        #expect(fields.map(\.name) == ["Stored", "Computed"])
        #expect(fields[0].metadata.storage == .stored)
        #expect(fields[1].metadata.storage == .computed)
        #expect(fields[1].metadata.access == .readWrite)
    }
}
