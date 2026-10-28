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

// Automatically resolved without @SBJDesignatedInit.
@SBJStructure
struct InferredInitializerFixture: Codable, Equatable {
    var x: Double
    var y: Double

    init(x horizontal: Double, _ y: Double = 2) {
        self.x = horizontal
        self.y = y
    }
}

@SBJStructure
struct InferredInitializerWithConvenienceFixture: Codable, Equatable {
    var name: String
    var count: Int

    init(name: String, count: Int) {
        self.name = name
        self.count = count
    }

    init(name: String) {
        self.init(name: name, count: 0)
    }
}

// A convenience overload can use the same parameter names while accepting
// different types. Only the signature that reconstructs the stored values
// directly is eligible for source export.
@SBJStructure
struct OverloadedInitializerReconstructionFixture: Codable, Equatable {
    var name: String
    var sections: [String]

    init(_ name: String = "", _ sections: [String] = []) {
        self.name = name
        self.sections = sections
    }

    init(_ name: String = "", _ sections: [Int]) {
        self.name = name
        self.sections = sections.map(String.init)
    }

    init<T: CustomStringConvertible>(_ name: T, _ sections: [String] = []) {
        self.name = name.description
        self.sections = sections
    }
}

struct InferredInitializerTests {
    @Test func reconstructsStoredTypesInsteadOfConversionOverloads() {
        let parameters = OverloadedInitializerReconstructionFixture.sbjSwiftInitializerParameters
        #expect(parameters.map(\.propertyName) == ["name", "sections"])
        #expect(parameters.map(\.label) == [nil, nil])
        let value = OverloadedInitializerReconstructionFixture("notes", ["one", "two"])
        let source = SBJSwiftEncoder().expression(for: value, nested: false)
        #expect(source.contains("OverloadedInitializerReconstructionFixture("))
        #expect(!source.contains("JSONDecoder().decode("))
    }

    @Test func mapsExternalAndUnlabeledParameters() {
        let parameters = InferredInitializerFixture.sbjSwiftInitializerParameters
        #expect(parameters.map(\.propertyName) == ["x", "y"])
        #expect(parameters.map(\.label) == ["x", nil])
        let source = SBJSwiftEncoder().expression(for: InferredInitializerFixture(x: 4, 5), nested: false)
        #expect(source.contains("x: 4"))
        #expect(!source.contains("y:"))
    }

    @Test func prefersUniqueCompleteSignatureOverConvenienceInitializer() {
        let parameters = InferredInitializerWithConvenienceFixture.sbjSwiftInitializerParameters
        #expect(parameters.map(\.propertyName) == ["name", "count"])
        let source = SBJSwiftEncoder().expression(for: InferredInitializerWithConvenienceFixture(name: "Test", count: 3), nested: false)
        #expect(source.contains("count: 3"))
    }
}

// No complete source initializer: the Codable contract is used rather than
// emitting a call to a nonexistent memberwise initializer.
@SBJStructure
struct CodableOnlyReconstructionFixture: Codable, Equatable {
    var name: String
    var score: Int

    init(name: String) {
        self.name = name
        self.score = name.count
    }
}

struct CodableReconstructionFallbackTests {
    @Test func usesCodableForIncompleteInitializer() throws {
        let value = CodableOnlyReconstructionFixture(name: "test")
        let expression = SBJSwiftEncoder().expression(for: value, nested: false)
        #expect(expression.contains("JSONDecoder().decode(CodableOnlyReconstructionFixture.self"))
        #expect(expression.contains("Data(base64Encoded:"))
        // Verify that the emitted payload reconstructs the actual value.
        let bytes = try JSONEncoder().encode(value)
        let copy = try JSONDecoder().decode(CodableOnlyReconstructionFixture.self, from: bytes)
        #expect(copy == value)
    }
}

@SBJStructure
struct DefaultMutableReconstructionFixture: Codable, Equatable {
    var name = "default"
    var count = 0
    init() {}
}

@SBJStructure
struct DefaultImmutableReconstructionFixture: Codable, Equatable {
    let id: Int
    var name: String
    init() {
        id = 42
        name = "default"
    }
}

struct ClosureReconstructionTests {
    @Test func defaultMutableStructureUsesInvokedClosure() {
        var value = DefaultMutableReconstructionFixture()
        value.name = "Changed"
        value.count = 12
        let source = SBJSwiftEncoder().expression(for: value, nested: false)
        #expect(source.hasPrefix("{\n"))
        #expect(source.contains("var value = DefaultMutableReconstructionFixture()"))
        #expect(source.contains("value.name = \"Changed\""))
        #expect(source.contains("value.count = 12"))
        #expect(source.hasSuffix("}()"))
        #expect(!source.contains("JSONDecoder"))
    }

    @Test func immutableStoredPropertyPreventsAssignmentReconstruction() {
        let source = SBJSwiftEncoder().expression(for: DefaultImmutableReconstructionFixture(), nested: false)
        #expect(source.contains("JSONDecoder().decode(DefaultImmutableReconstructionFixture.self"))
        #expect(!source.contains("value.id ="))
    }
}


// A closure reconstruction must remain an expression when nested in another
// collection; callers should not need a statement-oriented special case.
struct NestedClosureReconstructionTests {
    @Test func nestedMutableStructureRemainsAnExpression() {
        var item = DefaultMutableReconstructionFixture()
        item.name = "Nested"
        item.count = 17
        let source = SBJSwiftEncoder().expression(for: [item], nested: false)
        #expect(source.contains("var value = DefaultMutableReconstructionFixture()"))
        #expect(source.contains("value.name = \"Nested\""))
        #expect(source.contains("value.count = 17"))
        #expect(source.contains("return value"))
        #expect(source.contains("}()"))
        #expect(!source.contains("JSONDecoder"))
    }

    @Test func namedMutableClosureRemainsAnExpression() {
        let value = DefaultMutableReconstructionFixture()
        let source = SBJSwiftEncoder().encode(value, named: "example")
        #expect(source.hasPrefix("let example = {\n"))
        #expect(source.contains("var value = DefaultMutableReconstructionFixture()"))
        #expect(source.hasSuffix("}()"))
    }
}
