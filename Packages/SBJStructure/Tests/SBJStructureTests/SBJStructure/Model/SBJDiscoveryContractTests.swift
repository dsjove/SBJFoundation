import Foundation
import Testing
@testable import SBJStructure

@SBJStructure
private struct DiscoveryFixture {
    var title = ""
    private var secret = "private"
    fileprivate var fileSecret = "file"
    @SBJExclude var ignored = "excluded"
    @SBJFieldPresentation(exclude: true) var reportOnly = "report"
    private(set) var restricted = ""
    let immutable = ""
    var computed: String { title }
    private var privateComputed: String { secret }
    static var constant: String { "static" }
    var writable: String {
        get { title }
        set { title = newValue }
    }
    mutating func changeSecret() { secret = "different" }
}

@SBJStructure
private struct DiscoveryCodable: Codable {
    var name = "original"
    var noncoded = "runtime"
    private var secret = 42
    var computed: String { name }
    enum CodingKeys: String, CodingKey { case name = "label", secret }
}
private struct PlainLayout { var name: String; var number: Int; private var secret: Bool }
@SBJStructure
private struct StructuredLayout { var name: String; var number: Int; private var secret: Bool }

@SBJStructure
private enum PlainCase { case first, second }
@SBJStructure
private enum PlainPayload { case text(String), number(Int) }

@SBJStructure
private struct GetterFixture {
    var stored = ""
    var computed: String { fatalError("Metadata must not call a getter") }
}

@SBJStructure
private struct PrivateResourceFixture {
    private var reference = SBJReferencedContentID("private-resource")
    @SBJExclude var hiddenReference = SBJReferencedContentID("hidden-resource")
    var derived: SBJReferencedContentID { .init("not-stored") }
}

@SBJStructure
private struct NonCodableRuntimeFixture { var name = "" }

private final class ReadVisitor: SBJTypedPropertyVisitor {
    typealias Root = DiscoveryFixture
    var names: [String] = []
    var types: [Any.Type] = []
    func visit<Value>(_ keyPath: KeyPath<Root, Value>, metadata: SBJPropertyMetadata<Root>) {
        names.append(metadata.sourceName); types.append(Value.self)
    }
}

struct SBJDiscoveryContractTests {
    @Test func nonCodableDiscoveryRespectsReadAndWriteAccess() {
        let properties = DiscoveryFixture.sbjProperties
        #expect(properties.map(\.sourceName) == ["title", "reportOnly", "restricted", "immutable", "computed", "writable"])
        #expect(DiscoveryFixture.sbjProperties.filter { !$0.isPresentationExcluded }.map(\.sourceName) == ["title", "restricted", "immutable", "computed", "writable"])
        #expect(DiscoveryFixture.sbjMutableProperties.map(\.structuralMetadata.sourceName) == ["title", "reportOnly", "writable"])
        #expect(properties.first { $0.sourceName == "restricted" }?.access == .readOnly)
        let visitor = ReadVisitor()
        for property in properties { property.visitTypedProperty(with: visitor) }
        #expect(visitor.names == properties.map(\.sourceName))
        #expect(visitor.types.allSatisfy { $0 == String.self })
    }

    @Test func hiddenStateAffectsEquivalenceButNotContent() {
        let original = DiscoveryFixture()
        var changed = original
        #expect(!original.hasContent)
        #expect(original.sbjStructuralEquals(changed))
        changed.changeSecret()
        #expect(!original.sbjStructuralEquals(changed))
        #expect(!changed.hasContent)
        changed = original
        changed.ignored = "different excluded state"
        #expect(!original.sbjStructuralEquals(changed))
        #expect(!changed.hasContent)
        changed.title = "Meaningful"
        #expect(changed.hasContent)
    }

    @Test func codingKeysControlEncodingNotDiscovery() throws {
        let value = DiscoveryCodable()
        #expect(DiscoveryCodable.sbjProperties.map(\.sourceName) == ["name", "noncoded", "computed"])
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
        #expect(json["label"] as? String == "original")
        #expect(json["secret"] as? Int == 42)
        #expect(json["noncoded"] == nil)
        #expect(json["computed"] == nil)
    }

    @Test func macroDoesNotIntroduceInstanceStorage() {
        #expect(MemoryLayout<PlainLayout>.size == MemoryLayout<StructuredLayout>.size)
        #expect(MemoryLayout<PlainLayout>.stride == MemoryLayout<StructuredLayout>.stride)
        #expect(MemoryLayout<PlainLayout>.alignment == MemoryLayout<StructuredLayout>.alignment)
    }

    @Test func enumEquivalenceDoesNotRequireCodable() {
        #expect(PlainCase.first.sbjStructuralEquals(.first))
        #expect(!PlainCase.first.sbjStructuralEquals(.second))
        #expect(PlainPayload.text("a").sbjStructuralEquals(.text("a")))
        #expect(!PlainPayload.text("a").sbjStructuralEquals(.text("b")))
    }

    @Test func metadataDoesNotEvaluateComputedGetters() {
        #expect(GetterFixture.sbjProperties.map(\.sourceName) == ["stored", "computed"])
    }

    @Test func privateAndExcludedResourceStateRemainsDiscoverableToResourceTracking() {
        let value = PrivateResourceFixture()
        #expect(value.sbjReferencedContentIDs() == [.init("private-resource"), .init("hidden-resource")])
        #expect(value.sbjReferencedContentOccurrences().count == 2)
    }

    @Test func defaultConstructionWithDecodableFieldsDoesNotRequireCodableRoot() throws {
        let value = try SBJRuntimeConstruction.construct(NonCodableRuntimeFixture.self, fromJSON: Data(#"{"name":"created"}"#.utf8))
        #expect(value.name == "created")
    }
}
