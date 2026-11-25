import Foundation
import Testing
@testable import SBJLocalization

private struct StoredValue: SBJStructuralComparable, Hashable {
    let id: Int
    private let payload: String
    init(_ id: Int, _ payload: String) { self.id = id; self.payload = payload }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    func sbjStructuralEquals(_ other: Self) -> Bool {
        SBJStructuralCompare.equals(id, other.id) && SBJStructuralCompare.equals(payload, other.payload)
    }
}

private struct Opaque: Codable, Equatable, CustomStringConvertible {
    let value: Int
    static func == (lhs: Self, rhs: Self) -> Bool { true }
    var description: String { "opaque" }
}

struct StructuralEquivalenceTests {
    @Test func scalarValues() {
        #expect(SBJStructuralCompare.equals(42, 42))
        #expect(!SBJStructuralCompare.equals(42, 43))
        #expect(SBJStructuralCompare.equals(Data([1, 2]), Data([1, 2])))
        #expect(!SBJStructuralCompare.equals(Data([1, 2]), Data([2, 1])))
        #expect(SBJStructuralCompare.equals(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, UUID(uuidString: "00000000-0000-0000-0000-000000000001")!))
    }

    @Test func stringsCompareCodeUnits() {
        let composed = "\u{00E9}"
        let decomposed = "e\u{0301}"
        #expect(composed == decomposed)
        #expect(!SBJStructuralCompare.equals(composed, decomposed))
    }

    @Test func floatingPointState() {
        #expect(!SBJStructuralCompare.equals(0.0, -0.0))
        let nan = Double(bitPattern: 0x7ff8_0000_0000_0001)
        let other = Double(bitPattern: 0x7ff8_0000_0000_0002)
        #expect(SBJStructuralCompare.equals(nan, nan))
        #expect(!SBJStructuralCompare.equals(nan, other))
        #expect(!SBJStructuralCompare.equals(Float(0), -Float(0)))
        #expect(!SBJStructuralCompare.equals(CGFloat(0), -CGFloat(0)))
    }

    @Test func foundationValues() {
        #expect(SBJStructuralCompare.equals(Date(timeIntervalSinceReferenceDate: 12), Date(timeIntervalSinceReferenceDate: 12)))
        #expect(!SBJStructuralCompare.equals(Date(timeIntervalSinceReferenceDate: 12), Date(timeIntervalSinceReferenceDate: 13)))
        #expect(SBJStructuralCompare.equals(Duration.seconds(3), Duration.seconds(3)))
        #expect(!SBJStructuralCompare.equals(Duration.seconds(3), Duration.seconds(4)))
        #expect(SBJStructuralCompare.equals(Decimal(12), Decimal(12)))
        #expect(!SBJStructuralCompare.equals(Decimal(12), Decimal(13)))
        #expect(SBJStructuralCompare.equals(URL(string: "https://example.com/a")!, URL(string: "https://example.com/a")!))
        #expect(!SBJStructuralCompare.equals(URL(string: "https://example.com/a")!, URL(string: "https://example.com/b")!))
    }

    @Test func unsupportedTypesNeverProveEquivalence() {
        let lhs = Opaque(value: 1)
        let rhs = Opaque(value: 2)
        #expect(lhs == rhs)
        #expect(!SBJStructuralCompare.equals(lhs, rhs))
        #expect(!SBJStructuralCompare.equals(lhs, lhs))
        #expect(!SBJStructuralCompare.equals([lhs], [lhs]))
    }

    @Test func erasedTypesCannotBridgeIntoEquality() {
        #expect(!SBJStructuralCompare.equals(1 as Any, Int8(1) as Any))
        #expect(!SBJStructuralCompare.equals(1 as Any, Optional(1) as Any))
        #expect(SBJStructuralCompare.equals(1 as Any, 1 as Any))
        #expect(!SBJStructuralCompare.equals(Optional<Int>.none as Any, Optional<String>.none as Any))
    }

    @Test func nonCodableRecursiveContainers() {
        let a = StoredValue(1, "A")
        let b = StoredValue(1, "B")
        #expect(a == b)
        #expect(!SBJStructuralCompare.equals(a, b))
        #expect(!SBJStructuralCompare.equals(Optional(a), Optional(b)))
        #expect(SBJStructuralCompare.equals(Optional<StoredValue>.none, Optional<StoredValue>.none))
        #expect(!SBJStructuralCompare.equals(Optional(a), Optional<StoredValue>.none))
        #expect(!SBJStructuralCompare.equals([a], [b]))
        #expect(!SBJStructuralCompare.equals(Set([a]), Set([b])))
        #expect(!SBJStructuralCompare.equals([a: 1], [b: 1]))
        #expect(!SBJStructuralCompare.equals([1: a], [1: b]))
        #expect(SBJStructuralCompare.equals([1: [a]], [1: [a]]))
        #expect(SBJStructuralCompare.equals([StoredValue](), [StoredValue]()))
    }

    @Test func orderedAndUnorderedCollections() {
        #expect(!SBJStructuralCompare.equals([1, 2], [2, 1]))
        #expect(SBJStructuralCompare.equals(Set([1, 2]), Set([2, 1])))
        #expect(SBJStructuralCompare.equals([1: "A", 2: "B"], [2: "B", 1: "A"]))
        #expect(!SBJStructuralCompare.equals([1: "A"], [1: "B"]))
        #expect(!SBJStructuralCompare.equals(Set([1, 2]), Set([1, 3])))
    }

    @Test func unorderedCollectionsUseStructuralMatching() {
        let nan = Double(bitPattern: 0x7ff8_0000_0000_0001)
        let other = Double(bitPattern: 0x7ff8_0000_0000_0002)
        //#expect(nan.isNaN)
        #expect(SBJStructuralCompare.equals(Set([nan]), Set([nan])))
        #expect(SBJStructuralCompare.equals([nan: "value"], [nan: "value"]))
        #expect(!SBJStructuralCompare.equals(Set([nan]), Set([other])))
        #expect(!SBJStructuralCompare.equals([nan: "value"], [other: "value"]))
    }

    @Test func contentAndStateAreIndependent() {
        struct Model: SBJStructuralComparable, HasContentCheckable {
            private let identifier: Int
            let name: String
            init(_ identifier: Int, _ name: String) { self.identifier = identifier; self.name = name }
            var hasContent: Bool { name.hasContent }
            func sbjStructuralEquals(_ other: Self) -> Bool {
                identifier == other.identifier && SBJStructuralCompare.equals(name, other.name)
            }
        }
        let a = Model(1, "")
        let b = Model(2, "")
        #expect(!a.hasContent)
        #expect(!b.hasContent)
        #expect(!SBJStructuralCompare.equals(a, b))
        #expect(Model(1, "Character").hasContent)
        #expect(![a, b].hasContent)
        #expect(![1: a].hasContent)
    }
}
