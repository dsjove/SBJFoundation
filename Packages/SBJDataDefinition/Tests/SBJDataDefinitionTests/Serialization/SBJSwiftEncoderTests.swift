import Foundation
import Testing
@testable import SBJDataDefinition

@SBJStructure
public struct SwiftExportFixture: Codable, Equatable {
    var name: String = ""
    var tags: Set<String> = []
    var values: [String: Int] = [:]

    @SBJDesignatedInit
    init(name: String = "", tags: Set<String> = [], values: [String: Int] = [:]) {
        self.name = name
        self.tags = tags
        self.values = values
    }
}

struct SBJSwiftEncoderTests {
    @Test func exportsStructuredValueUsingDesignatedInitializerOrder() {
        let value = SwiftExportFixture(name: "sample", tags: ["beta", "alpha"], values: ["two": 2, "one": 1])
        let source = SBJSwiftEncoder().encode(value, named: "sample value")

        #expect(source.hasPrefix("let sampleValue = SwiftExportFixture("))
        #expect(source.contains("name: \"sample\""))
        #expect(source.range(of: "name:")!.lowerBound < source.range(of: "tags:")!.lowerBound)
        #expect(source.range(of: "tags:")!.lowerBound < source.range(of: "values:")!.lowerBound)
    }

    @Test func omitsArgumentsThatMatchDesignatedInitializerDefaults() {
        let source = SBJSwiftEncoder().encode(SwiftExportFixture(), named: "fixture")
        #expect(source == "let fixture = SwiftExportFixture()")
    }

    @Test func setAndDictionaryExportIsDeterministic() {
        let encoder = SBJSwiftEncoder()
        let setSource = encoder.expression(for: Set(["10", "2", "1"]))
        let dictionarySource = encoder.expression(for: ["10": 10, "2": 2, "1": 1])

        #expect(setSource == "[\n\t\"1\",\n\t\"10\",\n\t\"2\"\n]")
        #expect(dictionarySource == "[\n\t\"1\": 1,\n\t\"10\": 10,\n\t\"2\": 2\n]")
    }


    @Test func qualifiesEmptyInitializersInsideCollections() {
        let encoder = SBJSwiftEncoder()
        let values = [SwiftExportFixture(), SwiftExportFixture(name: "named")]
        let source = encoder.expression(for: values)

        #expect(source.contains("SwiftExportFixture()"))
        #expect(source.contains(".init(\n"))
        #expect(source.contains("name: \"named\""))
    }

    @Test func exportsSpecialFoundationValues() {
        let encoder = SBJSwiftEncoder()
        #expect(encoder.expression(for: URL(fileURLWithPath: "/tmp/a")) == "URL(fileURLWithPath: \"/tmp/a\")")
        #expect(encoder.expression(for: Data([1, 2, 255])) == "Data([1, 2, 255])")
        #expect(encoder.expression(for: Double.infinity) == ".infinity")
        #expect(encoder.expression(for: -Double.infinity) == "-.infinity")
        #expect(encoder.expression(for: Double.nan) == ".nan")
    }
}

@SBJStructure
struct RequiredInitializerDefaultFixture: Codable, Equatable {
    let name: String
    var count: Int

    @SBJDesignatedInit
    init(_ name: String, count: Int = 7) {
        self.name = name
        self.count = count
    }
}

@SBJStructure
struct NoContextFreeDefaultFixture: Codable, Equatable {
    let child: RequiredInitializerDefaultFixture

    @SBJDesignatedInit
    init(child: RequiredInitializerDefaultFixture) {
        self.child = child
    }
}

struct DesignatedInitializerDefaultsTests {
    @Test func synthesizesRequiredArgumentDefaults() {
        let result = RequiredInitializerDefaultFixture.sbjDefaultValue()
        #expect(result?.name == "")
        #expect(result?.count == 7)
    }

    @Test func exportsUnlabeledParameterInDesignatedOrder() {
        let result = RequiredInitializerDefaultFixture("Alice", count: 3)
        let expression = SBJSwiftEncoder().expression(for: result, nested: false)
        #expect(expression.hasPrefix("RequiredInitializerDefaultFixture("))
        #expect(expression.contains("\"Alice\""))
        #expect(expression.contains("count: 3"))
        #expect(!expression.contains("name:"))
    }

    @Test func synthesizesNestedStructuredDefaults() {
        let result = NoContextFreeDefaultFixture.sbjDefaultValue()
        #expect(result?.child.name == "")
        #expect(result?.child.count == 7)
    }
}
