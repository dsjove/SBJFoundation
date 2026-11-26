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
    case alternate(label: String)
    case numeric(label: Int)
}

@SBJStructure
struct SBJSemanticReadFixture {
    @SBJInteger(min: 1, max: 20)
    var level = 9
    static let levelNomenclature = SBJNomenclature(title: "Experience level", summary: "Current experience tier.", details: "Used for level-dependent calculations.", aliases: ["Character level", "CHARACTER LEVEL", "EXPERIENCE LEVEL"], accessibilityLabel: "TEST ACCESSIBILITY LABEL", accessibilityHint: "TEST ACCESSIBILITY HINT")
    @SBJString(allowedValues: ["Alpha", "Beta"], pattern: "[A-Za-z]+")
    var mode = "Alpha"
    static let modeNomenclature = SBJNomenclature(title: "Mode", details: "Character level may determine this mode.")
    let fixed = "Immutable value"
    var doubled: Int { level * 2 }
    @SBJArray(elementName: \SBJSemanticReadFixtureItem.name, minCount: 1, maxCount: 10)
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
    private func field(_ snapshot: SBJSemanticReadSnapshot, _ name: String) throws -> SBJSemanticKey {
        .field(try #require(snapshot.declarationIdentifier(for: [.field(name)])))
    }

    private func record(_ snapshot: SBJSemanticReadSnapshot, _ operation: SBJSemanticReadOperation, _ name: String) throws -> SBJSemanticReadResult {
        try snapshot.modelQuery(operation, keyPath: [field(snapshot, name)])
    }

    @Test func storedImmutableComputedAndVisibility() throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJSemanticReadFixture())
        #expect(try record(snapshot, .read, "level").readValue == .signed(9))
        #expect(try record(snapshot, .read, "doubled").readValue == .signed(18))
        #expect(try record(snapshot, .read, "fixed").readValue == .text("Immutable value"))
        let description = try record(snapshot, .describe, "level").metadata?["description"]?.label ?? ""
        #expect(description.contains("Experience level"))
        #expect(description.contains("Character level"))
        #expect(description.contains("Used for level-dependent calculations"))
        #expect(description.contains("Range 1–20"))
        #expect(!description.contains("Current experience tier."))
        let metadata = try record(snapshot, .describe, "level").metadata?["nomenclature"]
        #expect(metadata?["summary"] == .text("Current experience tier."))
        #expect(metadata?["title"] == .text("Experience level"))
        #expect(!description.contains("TEST ACCESSIBILITY"))
        #expect(snapshot.paths.allSatisfy { !$0.contains("hidden") && !$0.contains("excluded") })
        let all = try snapshot.modelQuery(.read, keyPath: [])
        #expect(!String(reflecting: all).contains("HIDDEN"))
        #expect(!String(reflecting: all).contains("EXCLUDED"))
    }

    @Test func staticDefinitionAndRootDiscovery() throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJSemanticReadFixture())
        let level = try #require(snapshot.entries.first { $0.path == "$/level" })
        #expect(level.aliases == ["Character level"])
        let items = snapshot.entries.filter { $0.path == "$/items/0" || $0.path == "$/items/1" }
        #expect(items.compactMap(\.position) == [1, 2])
        #expect(Set(snapshot.paths).count == snapshot.entries.count)
        let text = snapshot.structuralDescription()
        #expect(text.contains("Experience level,Character level"))
        #expect(!text.contains("Used for level-dependent calculations"))
        #expect(!text.contains("Immutable value"))
        #expect(!text.contains("HIDDEN ROOT VALUE"))
        #expect(!text.contains("Same"))
        #expect(text.contains("Absent type information"))
        #expect(!text.contains("Active case"))
        #expect(try SBJCompactStructureTestDecoder.expand(text) == snapshot.structuralDescription(usesTemplates: false))
        let declaredLevel = try #require(snapshot.declarationIdentifier(for: [.field("level")]))
        let root = try snapshot.modelQuery(.children, keyPath: [])
        #expect(root.childrenPage?.members.contains(where: { if case .field(let id, _) = $0 { return id == declaredLevel }; return false }) == true)
    }

    @Test func dictionaryMemberRulesAndNames() throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJSemanticReadFixture())
        let lookup = try field(snapshot, "lookup")
        let key = try #require(snapshot.declarationIdentifier(for: [.field("lookup"), .member, .field("key")]))
        let value = try #require(snapshot.declarationIdentifier(for: [.field("lookup"), .member, .field("value")]))
        let keyPath: [SBJSemanticKey] = [lookup, .name("a/b~c"), .field(key)]
        let valuePath: [SBJSemanticKey] = [lookup, .name("a/b~c"), .field(value)]
        #expect(try snapshot.modelQuery(.read, keyPath: keyPath).readValue == .text("a/b~c"))
        #expect(try snapshot.modelQuery(.read, keyPath: valuePath).readValue == .signed(23))
        #expect(try snapshot.modelQuery(.describe, keyPath: keyPath).metadata?["description"]?.label?.contains("Minimum length 1") == true)
        #expect(try snapshot.modelQuery(.describe, keyPath: [lookup, .field(value)]).metadata?["description"]?.label?.contains("Range 0–100") == true)
        let dictionary = try field(snapshot, "typedKeys")
        let entryValue = try #require(snapshot.declarationIdentifier(for: [.field("typedKeys"), .member, .field("value")]))
        let name = try #require(snapshot.declarationIdentifier(for: [.field("typedKeys"), .member, .field("value"), .field("name")]))
        #expect(try snapshot.modelQuery(.read, keyPath: [dictionary, .name("second"), .field(entryValue), .field(name)]).readValue == .text("Quartz"))
        #expect(try snapshot.modelQuery(.read, keyPath: [dictionary, .name("Quartz"), .field(entryValue), .field(name)]).readValue == .text("Quartz"))
        let member = try snapshot.modelQuery(.children, keyPath: [dictionary]).childrenPage?.members.first
        #expect(member == .member(key: "second", title: "Quartz", ordinal: nil, ambiguous: false))
    }

    @Test func absenceEmptyAndAssociatedPayloads() throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJSemanticReadFixture())
        #expect(try record(snapshot, .count, "empty").countValue == 0)
        #expect(try record(snapshot, .read, "empty").readValue == .array([]))
        #expect(try record(snapshot, .read, "absent").readValue == .null)
        #expect(try snapshot.modelQuery(.read, keyPath: [field(snapshot, "optionalItems"), .ordinal(2)]).readValue == .null)
        #expect(try record(snapshot, .read, "choice").readValue?["caseName"] == .text("named"))
        #expect(try record(snapshot, .read, "inactiveChoice").readValue?["caseName"] == .text("none"))
        #expect(!snapshot.paths.contains("$/inactiveChoice/payload"))
        #expect(!snapshot.paths.contains("$/absent/neverInstantiatedField"))
        #expect(try record(snapshot, .count, "absentCollection").countValue == 0)
        let fieldID = try #require(snapshot.declarationIdentifier(for: [.field("empty"), .member, .field("neverInstantiatedField")]))
        #expect(try snapshot.modelQuery(.describe, keyPath: [field(snapshot, "empty"), .field(fieldID)]).metadata?["title"] == .text("Absent type information"))
    }

    @Test func exactNumbersUnitsAndReadOnlyFailures() throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJSemanticReadFixture())
        #expect(try record(snapshot, .read, "exactUnsigned").readValue == .unsigned(.max))
        #expect(try record(snapshot, .read, "exactDecimal").readValue == .decimal(Decimal(string: "1234567890.123456789")!))
        #expect(try record(snapshot, .read, "weight").readValue == .text(SBJSemanticReadFixture().weight.presentedValue))
        #expect(!snapshot.paths.contains("$/weight/value"))
        #expect(!snapshot.paths.contains("$/weight/unit"))
        #expect(snapshot.declarationIdentifier(for: [.field("weight"), .field("value")]) == nil)
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(0)]).failure != nil)
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(snapshot.declarationCount + 1)]).failure != nil)
        #expect(try snapshot.modelQuery(.read, keyPath: [.name("level")]).failure != nil)
        #expect(try record(snapshot, .count, "level").failure != nil)
    }

    @Test func onDemandCollectionKeysTrackNamesWithoutChangingDeclarations() throws {
        var fixture = SBJSemanticReadFixture()
        fixture.items[0].name = "Pebble"
        let before = try SBJSemanticReadSnapshot(instance: fixture)
        let items = String(try #require(before.declarationIdentifier(for: [.field("items")])))
        let rank = String(try #require(before.declarationIdentifier(for: [.field("items"), .member, .field("rank")])))
        let keys = try before.modelQuery(.keys, stringKeyPath: [items])
        #expect(keys.available?.members.map(\.key) == ["Pebble", "Same"])
        #expect(keys.readValue == nil)
        let incomplete = try before.modelQuery(.read, stringKeyPath: [items, rank])
        #expect(incomplete.memberRequest != nil)
        #expect(incomplete.memberRequest?.action == .insert)
        #expect(incomplete.memberRequest?.keyPosition == 2)
        #expect(incomplete.memberRequest?.available == keys.available)
        #expect(try before.modelQuery(.read, stringKeyPath: [items, "Pebble", rank]).readValue == .signed(7))
        fixture.items[0].name = "Quartz"
        let after = try SBJSemanticReadSnapshot(instance: fixture)
        #expect(before.structuralDescription() == after.structuralDescription())
        #expect(try after.modelQuery(.keys, stringKeyPath: [items]).available?.members.map(\.key) == ["Quartz", "Same"])
        let stale = try after.modelQuery(.read, stringKeyPath: [items, "Pebble", rank])
        #expect(stale.memberRequest?.action == .replace)
        #expect(stale.available?.members.map(\.key) == ["Quartz", "Same"])
    }

    @Test func collectionKeyDiscoveryHandlesDuplicatesEmptyAndDictionary() throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJSemanticReadFixture())
        let items = String(try #require(snapshot.declarationIdentifier(for: [.field("items")])))
        let keys = try snapshot.modelQuery(.keys, stringKeyPath: [items])
        #expect(keys.available?.members.map(\.key) == ["@1", "@2"])
        #expect(keys.available?.members.first?.title == "Same")
        let empty = String(try #require(snapshot.declarationIdentifier(for: [.field("empty")])))
        #expect(try snapshot.modelQuery(.keys, stringKeyPath: [empty]).available?.members == [])
        let dictionary = String(try #require(snapshot.declarationIdentifier(for: [.field("typedKeys")])))
        let dictionaryKeys = try snapshot.modelQuery(.keys, stringKeyPath: [dictionary])
        #expect(dictionaryKeys.available?.members.map(\.key) == ["second"])
        #expect(dictionaryKeys.available?.members.first?.title == "Quartz")
        let level = String(try #require(snapshot.declarationIdentifier(for: [.field("level")])))
        #expect(try snapshot.modelQuery(.keys, stringKeyPath: [level]).failure != nil)
    }

    @Test func independentInstanceSchemasAndRootScalars() throws {
        var fixture = SBJSemanticReadFixture()
        let before = try SBJSemanticReadSnapshot(instance: fixture)
        fixture.level = 12
        fixture.lookup = ["new-key": 77]
        let after = try SBJSemanticReadSnapshot(instance: fixture)
        #expect(try record(before, .read, "doubled").readValue == .signed(18))
        #expect(try record(after, .read, "doubled").readValue == .signed(24))
        #expect(before.structuralDescription() == after.structuralDescription())
        #expect(before.paths.contains("$/lookup/key:a~1b~0c/value"))
        #expect(!after.paths.contains("$/lookup/key:a~1b~0c/value"))
        #expect(after.paths.contains("$/lookup/key:new-key/value"))
        let scalar = try SBJSemanticReadSnapshot(instance: 42)
        #expect(try scalar.modelQuery(.read, keyPath: []).readValue == .signed(42))
    }

    @Test func staticDefinitionIgnoresCollectionCountsOptionalPresenceAndActiveCases() throws {
        let original = SBJSemanticReadFixture()
        var changed = original
        changed.items = []
        changed.empty = [.init()]
        changed.absent = .init()
        changed.absentCollection = [.init()]
        changed.optionalItems = []
        changed.tags = []
        changed.lookup = [:]
        changed.choice = .inactive(neverActivePayload: .init())
        let before = try SBJSemanticReadSnapshot(instance: original)
        let after = try SBJSemanticReadSnapshot(instance: changed)
        #expect(before.structuralDescription() == after.structuralDescription())
        #expect(before.declarationCount == after.declarationCount)
        #expect(before.entries.count != after.entries.count)
    }

    @Test func keyPathsReadNamedAndOrdinalMembers() throws {
        var fixture = SBJSemanticReadFixture()
        fixture.items[1].name = "Second"
        let snapshot = try SBJSemanticReadSnapshot(instance: fixture)
        let level = try #require(snapshot.declarationIdentifier(for: [.field("level")]))
        let items = try #require(snapshot.declarationIdentifier(for: [.field("items")]))
        let rank = try #require(snapshot.declarationIdentifier(for: [.field("items"), .member, .field("rank")]))
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(level)]).readValue == .signed(9))
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(rank)]).failure != nil)
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(items), .name("Second"), .field(rank)]).readValue == .signed(8))
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(items), .ordinal(1), .field(rank)]).readValue == .signed(7))
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(items), .ordinal(0)]).failure != nil)
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(items), .ordinal(3)]).failure != nil)
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(items), .field(rank)]).failure != nil)
        let list = try snapshot.modelQuery(.children, keyPath: [.field(items)], childrenLimit: 1)
        #expect(list.childrenPage?.members.first == .member(key: "Same", title: nil, ordinal: 1, ambiguous: false))
        #expect(list.childrenPage?.nextOffset == 1)
        let next = try snapshot.modelQuery(.children, keyPath: [.field(items)], childrenOffset: 1, childrenLimit: 1)
        #expect(next.childrenPage?.members.first == .member(key: "Second", title: nil, ordinal: 2, ambiguous: false))
        #expect(next.childrenPage?.nextOffset == nil)
        let duplicate = try SBJSemanticReadSnapshot(instance: SBJSemanticReadFixture())
        #expect(try duplicate.modelQuery(.read, keyPath: [.field(items), .name("Same"), .field(rank)]).failure != nil)
    }

    @Test func dictionaryAndSetPaths() throws {
        let snapshot = try SBJSemanticReadSnapshot(instance: SBJSemanticReadFixture())
        let dictionary = try #require(snapshot.declarationIdentifier(for: [.field("lookup")]))
        let value = try #require(snapshot.declarationIdentifier(for: [.field("lookup"), .member, .field("value")]))
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(dictionary), .name("a/b~c"), .field(value)]).readValue == .signed(23))
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(dictionary), .name("nil"), .field(value)]).state == .unset)
        let tags = try #require(snapshot.declarationIdentifier(for: [.field("tags")]))
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(tags), .name("North")]).readValue == .text("North"))
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(tags), .ordinal(1)]).failure != nil)
    }

    @Test func flattenedEnumPayloadReadsOnlyCompatibleActiveCases() throws {
        var fixture = SBJSemanticReadFixture()
        let before = try SBJSemanticReadSnapshot(instance: fixture)
        let choice = try #require(before.declarationIdentifier(for: [.field("choice")]))
        let label = try #require(before.declarationIdentifier(for: [.field("choice"), .enumPayload(["named", "alternate"], "Label")]))
        let numeric = try #require(before.declarationIdentifier(for: [.field("choice"), .enumPayload(["numeric"], "Label")]))
        #expect(try before.modelQuery(.read, keyPath: [.field(choice), .field(label)]).readValue == .text("Chosen"))
        #expect(try before.modelQuery(.read, keyPath: [.field(choice), .field(numeric)]).state == .inactive)
        fixture.choice = .numeric(label: 42)
        let after = try SBJSemanticReadSnapshot(instance: fixture)
        #expect(before.structuralDescription() == after.structuralDescription())
        #expect(try after.modelQuery(.read, keyPath: [.field(choice), .field(numeric)]).readValue == .signed(42))
        #expect(try after.modelQuery(.read, keyPath: [.field(choice), .field(label)]).readValue == nil)
    }

    @Test func optionalAndAtomicPaths() throws {
        var fixture = SBJSemanticReadFixture()
        fixture.absentCollection = []
        let snapshot = try SBJSemanticReadSnapshot(instance: fixture)
        let absent = try #require(snapshot.declarationIdentifier(for: [.field("absent")]))
        let child = try #require(snapshot.declarationIdentifier(for: [.field("absent"), .field("neverInstantiatedField")]))
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(absent), .field(child)]).state == .unset)
        #expect(try snapshot.modelQuery(.describe, keyPath: [.field(absent), .field(child)]).metadata?["title"] == .text("Absent type information"))
        let optional = try #require(snapshot.declarationIdentifier(for: [.field("absentCollection")]))
        let count = try snapshot.modelQuery(.count, keyPath: [.field(optional)])
        #expect(count.countValue == 1)
        #expect(count.memberCount == 0)
        let weight = try #require(snapshot.declarationIdentifier(for: [.field("weight")]))
        #expect(try snapshot.modelQuery(.read, keyPath: [.field(weight)]).readValue == .text(fixture.weight.presentedValue))
    }

    #if DEBUG
    @Test func canonicalSampleModel() throws {
        let sample = SBJStructureSampleModel()
        let snapshot = try SBJSemanticReadSnapshot(instance: sample)
        #expect(snapshot.paths.contains("$/ingredients/0/name"))
        #expect(snapshot.paths.contains("$/substitutions/key:Pasta/value"))
        #expect(snapshot.paths.contains("$/substitutionsInstruction/payload/Alternatives/key:pasta/value"))
        #expect(snapshot.paths.contains("$/optionalCookingInstruction/payload/Value"))
        let ingredients = try field(snapshot, "ingredients")
        let name = try #require(snapshot.declarationIdentifier(for: [.field("ingredients"), .member, .field("name")]))
        #expect(try snapshot.modelQuery(.read, keyPath: [ingredients, .ordinal(1), .field(name)]).readValue == .text("Red bell pepper"))
        #expect(!snapshot.paths.contains("$/importSource"))
    }
    #endif
}
