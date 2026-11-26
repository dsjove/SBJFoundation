import Foundation
import SBJLocalization
import SBJStructure
import Testing
@testable import SBJStructuredAI

@SBJStructure
struct SBJSemanticReadFixtureItem: Codable, Hashable {
    var name: String = "Unassigned"
    @SBJInteger(range: 1...30)
    var rank: Int = 3
    static let rankNomenclature = SBJNomenclature(title: "Rank number", summary: "Relative training rank.", aliases: ["Training tier"])
    @SBJFieldPresentation(exclude: true)
    var hiddenItem = "HIDDEN ITEM VALUE"
}

@SBJStructure
struct SBJSemanticReadFixtureAbsent: Codable, Hashable {
    var neverInstantiatedField: String = "Never created"
    static let neverInstantiatedFieldNomenclature = SBJNomenclature(title: "Absent type information", details: "Describes the type even when its instance is absent.")
}

@SBJStructure
enum SBJSemanticReadFixtureKey: String, CaseIterable, Codable, Hashable {
    case first = "raw-first"
    case second = "raw-second"
}

@SBJStructure
enum SBJSemanticReadFixtureChoice: Codable {
    case none
    case named(label: String, amount: Int?)
    case inactive(neverActivePayload: SBJSemanticReadFixtureAbsent)
}

@SBJStructure
struct SBJSemanticReadFixture {
    @SBJInteger(min: 1, max: 20)
    var level = 9
    static let levelNomenclature = SBJNomenclature(title: "Experience level", summary: "Current experience tier.", details: "Used for level-dependent calculations.", aliases: ["Character level"], accessibilityLabel: "TEST ACCESSIBILITY LABEL", accessibilityHint: "TEST ACCESSIBILITY HINT")
    @SBJString(allowedValues: ["Alpha", "Beta"], pattern: "[A-Za-z]+")
    var mode = "Alpha"
    static let modeNomenclature = SBJNomenclature(title: "Mode", details: "Character level may determine this mode.")
    let fixed = "Immutable value"
    var doubled: Int { level * 2 }
    @SBJArray(minCount: 1, maxCount: 10)
    @SBJArrayPresentation(title: \SBJSemanticReadFixtureItem.name)
    var items = [SBJSemanticReadFixtureItem(name: "Same", rank: 7), SBJSemanticReadFixtureItem(name: "Same", rank: 8)]
    var empty: [SBJSemanticReadFixtureAbsent] = []
    var absent: SBJSemanticReadFixtureAbsent? = nil
    var absentCollection: [SBJSemanticReadFixtureItem]? = nil
    var optionalItems: [Int?] = [2, nil, 3]
    var tags: Set<String> = ["North", "South"]
    @SBJDictionary(key: [SBJStringRules(minLength: 1)], value: [SBJIntegerRules(min: 0, max: 100)])
    var lookup: [String: Int?] = ["a/b~c": 23, "nil": nil]
    var typedKeys: [SBJSemanticReadFixtureKey: SBJSemanticReadFixtureItem] = [.second: .init(name: "Quartz", rank: 11)]
    var choice = SBJSemanticReadFixtureChoice.named(label: "Chosen", amount: nil)
    var inactiveChoice: SBJSemanticReadFixtureChoice = .none
    @SBJUnitValue(min: 0, unitMutable: true)
    var weight = UnitValue<MassUnit>(2.5, unit: .kilogram)
    var exactUnsigned: UInt64 = .max
    var exactDecimal = Decimal(string: "1234567890.123456789")!
    @SBJFieldPresentation(exclude: true)
    var hidden = "HIDDEN ROOT VALUE"
    @SBJExclude
    var excluded = "EXCLUDED ROOT VALUE"
}

@Suite("Read-only instance access")
struct SBJSemanticReadSnapshotTests {
    private func record(_ snapshot: SBJSemanticReadSnapshot, _ operation: SBJSemanticReadOperation = .read, _ path: String) throws -> SBJSemanticValue {
        let rows = try #require(try snapshot.query(operation, paths: [path]).elements)
        return try #require(rows.first)
    }

    @Test func storedImmutableComputedAndVisibility() throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJSemanticReadFixture())
        #expect(try record(snapshot, .read, "$/level")["value"] == .signed(9))
        #expect(try record(snapshot, .read, "$/doubled")["value"] == .signed(18))
        #expect(try record(snapshot, .read, "$/fixed")["value"] == .text("Immutable value"))
        let description = try record(snapshot, .describe, "$/level")["description"]?.label ?? ""
        #expect(description.contains("Experience level"))
        #expect(description.contains("Character level"))
        #expect(description.contains("Used for level-dependent calculations"))
        #expect(description.contains("Range 1–20"))
        #expect(!description.contains("Current experience tier."))
        #expect(!description.contains("TEST ACCESSIBILITY"))
        #expect(snapshot.paths.allSatisfy { !$0.contains("hidden") && !$0.contains("excluded") })
        let all = try snapshot.query(.read, paths: ["$"])
        #expect(!String(reflecting: all).contains("HIDDEN"))
        #expect(!String(reflecting: all).contains("EXCLUDED"))
    }

    @Test func discoverByAliasAndItemLabel() throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJSemanticReadFixture())
        let alias = try #require(snapshot.find("Character level")["matches"]?.elements)
        #expect(alias.first?["path"] == .text("$/level"))
        let items = try #require(snapshot.find("Same", limit: 2)["matches"]?.elements)
        #expect(items.count == 2)
        #expect(Set(items.compactMap { $0["path"]?.label }) == Set(["$/items/0", "$/items/1"]))
    }

    @Test func childrenCanBePagedWithoutRepeatingDescriptions() throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJSemanticReadFixture())
        let first = try #require(try snapshot.query(.children, paths: ["$/items"], childrenLimit: 1).elements?.first)
        #expect(first["totalChildren"] == .signed(2))
        #expect(first["nextOffset"] == .signed(1))
        let firstPage = try #require(first["children"]?.elements)
        #expect(firstPage.count == 1)
        #expect(firstPage.first?["path"] == .text("$/items/0"))
        #expect(firstPage.first?["description"] == nil)
        let second = try #require(try snapshot.query(.children, paths: ["$/items"], childrenOffset: 1, childrenLimit: 1).elements?.first)
        #expect(second["nextOffset"] == nil)
        #expect(second["children"]?.elements?.first?["path"] == .text("$/items/1"))
    }

    @Test func collectionAddressesAndTypedDictionaryKeys() throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJSemanticReadFixture())
        #expect(try record(snapshot, .count, "$/items")["count"] == .signed(2))
        #expect(try record(snapshot, .read, "$/items/0/rank")["value"] == .signed(7))
        #expect(try record(snapshot, .read, "$/items/1/rank")["value"] == .signed(8))
        #expect(snapshot.entries.filter { $0.path == "$/items/0" || $0.path == "$/items/1" }.map(\.title) == ["Same", "Same"])
        #expect(try record(snapshot, .count, "$/tags")["count"] == .signed(2))
        #expect(try record(snapshot, .read, "$/lookup/key:a~1b~0c/key")["value"] == .text("a/b~c"))
        #expect(try record(snapshot, .read, "$/lookup/key:a~1b~0c/value")["value"] == .signed(23))
        #expect(try record(snapshot, .read, "$/lookup/key:nil/value")["value"] == .null)
        #expect(try record(snapshot, .read, "$/typedKeys/key:second/key")["value"] == .text("second"))
        #expect(try record(snapshot, .read, "$/typedKeys/key:second/value/name")["value"] == .text("Quartz"))
        let key = try record(snapshot, .describe, "$/lookup/key:a~1b~0c/key")["description"]?.label ?? ""
        let value = try record(snapshot, .describe, "$/lookup/key:a~1b~0c/value")["description"]?.label ?? ""
        #expect(key.contains("Minimum length 1"))
        #expect(value.contains("Range 0–100"))
        #expect(snapshot.instanceAccessDescription.contains("$/items/0: \"Same\""))
    }

    @Test func absenceEmptyAndAssociatedPayloads() throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJSemanticReadFixture())
        #expect(try record(snapshot, .count, "$/empty")["count"] == .signed(0))
        #expect(try record(snapshot, .read, "$/empty")["value"] == .array([]))
        #expect(try record(snapshot, .read, "$/absent")["value"] == .null)
        #expect(try record(snapshot, .read, "$/optionalItems/1")["value"] == .null)
        #expect(try record(snapshot, .read, "$/choice/caseName")["value"] == .text("named"))
        #expect(try record(snapshot, .read, "$/choice/payload/Label")["value"] == .text("Chosen"))
        #expect(try record(snapshot, .read, "$/choice/payload/Amount")["value"] == .null)
        #expect(try record(snapshot, .read, "$/inactiveChoice/caseName")["value"] == .text("none"))
        #expect(!snapshot.paths.contains("$/inactiveChoice/payload"))
        #expect(!snapshot.paths.contains("$/absent/neverInstantiatedField"))
        #expect(throws: SBJSemanticReadError.notACollection("$/absentCollection")) { try snapshot.query(.count, paths: ["$/absentCollection"]) }
    }

    @Test func exactNumbersUnitsAndReadOnlyFailures() throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJSemanticReadFixture())
        #expect(try record(snapshot, .read, "$/exactUnsigned")["value"] == .unsigned(.max))
        #expect(try record(snapshot, .read, "$/exactDecimal")["value"] == .decimal(Decimal(string: "1234567890.123456789")!))
        #expect(try record(snapshot, .read, "$/weight/value")["value"] == .number(2.5))
        #expect(try record(snapshot, .read, "$/weight/unit")["value"] == .text("kilogram"))
        #expect(throws: SBJSemanticReadError.unknownPath("$/hidden")) { try snapshot.query(.read, paths: ["$/hidden"]) }
        #expect(throws: SBJSemanticReadError.noPaths) { try snapshot.query(.read, paths: []) }
        #expect(throws: SBJSemanticReadError.notACollection("$/level")) { try snapshot.query(.count, paths: ["$/level"]) }
    }

    @Test func independentInstanceSchemasAndRootScalars() throws {
        var fixture = SBJSemanticReadFixture()
        let before = try SBJSemanticReadSnapshot(instance: fixture)
        fixture.level = 12
        fixture.lookup = ["new-key": 77]
        let after = try SBJSemanticReadSnapshot(instance: fixture)
        #expect(try record(before, .read, "$/doubled")["value"] == .signed(18))
        #expect(try record(after, .read, "$/doubled")["value"] == .signed(24))
        #expect(before.paths.contains("$/lookup/key:a~1b~0c/value"))
        #expect(!after.paths.contains("$/lookup/key:a~1b~0c/value"))
        #expect(after.paths.contains("$/lookup/key:new-key/value"))
        let scalar = try SBJSemanticReadSnapshot(instance: 42)
        #expect(scalar.paths == ["$"])
        #expect(try record(scalar, .read, "$")["value"] == .signed(42))
    }

    #if DEBUG
    @Test func canonicalSampleModel() throws {
        let sample = SBJStructureSampleModel()
        let snapshot = try SBJSemanticReadSnapshot(instance: sample)
        #expect(snapshot.paths.contains("$/ingredients/0/name"))
        #expect(snapshot.paths.contains("$/substitutions/key:Pasta/value"))
        #expect(snapshot.paths.contains("$/substitutionsInstruction/payload/Alternatives/key:pasta/value"))
        #expect(snapshot.paths.contains("$/optionalCookingInstruction/payload/Value"))
        #expect(try record(snapshot, .read, "$/ingredients/0/name")["value"] == .text("Red bell pepper"))
        #expect(!snapshot.paths.contains("$/importSource"))
    }
    #endif
}
