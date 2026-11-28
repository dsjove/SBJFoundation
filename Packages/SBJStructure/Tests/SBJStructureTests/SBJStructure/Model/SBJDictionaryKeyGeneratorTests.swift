import Testing
@testable import SBJStructure

@SBJStructure
private struct DictionaryGeneratorFixture {
    @SBJDictionary(keyGenerator: { (existing: [Int: String], value: String) -> Int? in
        let candidate = value.count
        return existing.keys.contains(candidate) ? nil : candidate
    })
    var named: [Int: String] = [:]
    var plain: [Int: String] = [:]

    @SBJDictionary(keyGenerator: { (existing: [Int: String], value: String) -> Int? in
        (existing.keys.max() ?? 0) + value.count
    })
    var optional: [Int: String]? = nil
}

@Test func dictionaryKeyGeneratorMetadata() throws {
    let generator = try #require(DictionaryGeneratorFixture.propertyMetadata(for: \.named)?.dictionaryKeyGenerator)
    #expect(generator.key(for: [1: "one"], value: "new") == 3)
    #expect(generator.key(for: [3: "old"], value: "new") == nil)
    #expect(DictionaryGeneratorFixture.propertyMetadata(for: \.plain)?.dictionaryKeyGenerator == nil)
    let optional = try #require(DictionaryGeneratorFixture.propertyMetadata(for: \.optional)?.dictionaryKeyGenerator)
    #expect(optional.key(for: [3: "old"], value: "new") == 6)
}
