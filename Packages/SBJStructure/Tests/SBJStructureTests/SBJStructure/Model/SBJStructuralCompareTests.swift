import Testing
@testable import SBJStructure

private struct EquatableLeaf: Codable, Equatable {
    var identity: Int
    var payload: String

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.identity == rhs.identity
    }
}

private struct EncodedLeaf: Codable {
    var value: String
}

@SBJStructure
private struct GeneratedStructuralValue: Codable, Equatable {
    var identity: Int
    var payload: String

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.identity == rhs.identity
    }
}

@SBJStructure
private struct StructuralContainer: Codable {
    var equatableLeaf: EquatableLeaf
    var encodedLeaf: EncodedLeaf
    var generatedValues: [GeneratedStructuralValue]
}

@SBJStructure
private struct StructuralOverride: Codable {
    var identity: Int
    var ignoredPayload: String

    func sbjStructuralEquals(_ other: Self) -> Bool {
        identity == other.identity
    }
}

struct SBJStructuralCompareTests {
    @Test func ordinaryEquatableValueUsesItsEquality() {
        let lhs = EquatableLeaf(identity: 1, payload: "left")
        let rhs = EquatableLeaf(identity: 1, payload: "right")
        #expect(SBJStructuralCompare.equals(lhs, rhs))
    }

    @Test func opaqueCodableFallsBackToEncodedComparison() {
        #expect(SBJStructuralCompare.equals(EncodedLeaf(value: "same"), EncodedLeaf(value: "same")))
        #expect(!SBJStructuralCompare.equals(EncodedLeaf(value: "left"), EncodedLeaf(value: "right")))
    }

    @Test func generatedStructureUsesStructuralFieldsInsteadOfBusinessEquatable() {
        let lhs = GeneratedStructuralValue(identity: 1, payload: "left")
        let rhs = GeneratedStructuralValue(identity: 1, payload: "right")
        #expect(lhs == rhs)
        #expect(!lhs.sbjStructuralEquals(rhs))
        #expect(!SBJStructuralCompare.equals(lhs, rhs))
    }

    @Test func collectionsRecurseUsingStructuralComparison() {
        let lhs = [GeneratedStructuralValue(identity: 1, payload: "left")]
        let rhs = [GeneratedStructuralValue(identity: 1, payload: "right")]
        #expect(lhs == rhs)
        #expect(!lhs.sbjStructuralEquals(rhs))
        #expect(!SBJStructuralCompare.equals(lhs, rhs))
    }

    @Test func generatedContainerComposesFieldStrategies() {
        let lhs = StructuralContainer(
            equatableLeaf: .init(identity: 1, payload: "left"),
            encodedLeaf: .init(value: "same"),
            generatedValues: [.init(identity: 1, payload: "same")]
        )
        var rhs = lhs
        rhs.equatableLeaf.payload = "ignored by Equatable"
        #expect(lhs.sbjStructuralEquals(rhs))
        rhs.encodedLeaf.value = "changed"
        #expect(!lhs.sbjStructuralEquals(rhs))
    }

    @Test func dictionaryComparisonPreservesPresentOptionalNilValues() {
        var lhs: [String: Int?] = [:]
        var rhs: [String: Int?] = [:]
        lhs.updateValue(nil, forKey: "value")
        rhs.updateValue(nil, forKey: "value")
        #expect(lhs.sbjStructuralEquals(rhs))
        rhs["other"] = 1
        #expect(!lhs.sbjStructuralEquals(rhs))
    }

    @Test func userCanOverrideGeneratedStructuralComparisonAndCallDefault() {
        let lhs = StructuralOverride(identity: 1, ignoredPayload: "left")
        let rhs = StructuralOverride(identity: 1, ignoredPayload: "right")
        #expect(lhs.sbjStructuralEquals(rhs))
        #expect(!lhs._sbjStructuralEquals(rhs))
    }
}
