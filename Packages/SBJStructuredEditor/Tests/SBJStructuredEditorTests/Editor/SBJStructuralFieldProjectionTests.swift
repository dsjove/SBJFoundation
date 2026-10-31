import Foundation
import Testing
import SBJDataDefinition
#if canImport(SwiftUI)
import SwiftUI
#endif
@testable import SBJStructuredEditor

@SBJStructure
private struct StructuralProjectionFixture: Codable {
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
        let fields = SBJStructuralFieldProjection.fields(of: StructuralProjectionFixture.self)
        #expect(fields.map(\.name) == ["First", "Count"])
        #expect(fields.map { $0.editableField.structuralMetadata?.sourceName } == ["first", "count"])
        #expect(ObjectIdentifier(fields[0].editableField.valueType) == ObjectIdentifier(String.self))
        #expect(ObjectIdentifier(fields[1].editableField.valueType) == ObjectIdentifier(Int.self))
        let model = StructuralProjectionFixture()
        #expect(fields[0].editableField.value(in: model) as? String == "")
        #expect(fields[1].editableField.value(in: model) as? Int == 0)
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
        #expect(StructuralChildFixture._sbjStructuralFieldCount == 1)
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
        let descriptor = SBJEditorPropertyDescriptor<StructuralProjectionFixture>(name: "First", \.first)
        #expect(ObjectIdentifier(descriptor.editableField.valueType) == ObjectIdentifier(String.self))
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
        let fields = SBJStructuralFieldProjection.fields(of: StructuralProjectionFixture.self)
        let locations = SBJEditorStructuralLocations.resolve(fields, of: StructuralProjectionFixture.self)
        let schema = SBJStructuralTraversal.schema(of: StructuralProjectionFixture.self)
        #expect(locations.map(\.identity) == schema.map(\.identityComponent))
        #expect(locations.map(\.location) == schema.map(\.locationComponent))
    }

    @Test @MainActor
    func presentationOnlyFieldsDoNotClaimStructuralIdentity() {
        let fields = [SBJEditorPropertyDescriptor<StructuralProjectionFixture>(
            nonStructuralName: "Temporary", \.first
        )]
        let locations = SBJEditorStructuralLocations.resolve(fields, of: StructuralProjectionFixture.self)
        #expect(locations[0].identity == "editor-property:Temporary")
        #expect(locations[0].location == "editor-field:0")
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
        #expect(fields[1].editableField.structuralMetadata?.hints.contains {
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
    func computedPresentationFieldsRemainOutsideSchema() {
        let fields = SBJStructuralFieldProjection.fields(of: ComputedProjectionFixture.self)
        #expect(fields.map(\.name) == ["Stored", "Computed"])
        #expect(fields[0].editableField.structuralMetadata != nil)
        #expect(fields[1].editableField.structuralMetadata == nil)
    }
}
