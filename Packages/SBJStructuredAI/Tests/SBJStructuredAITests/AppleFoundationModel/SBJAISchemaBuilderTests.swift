#if canImport(FoundationModels) && !os(watchOS) && !os(tvOS)
import Foundation
import FoundationModels
import SBJStructure
import Testing
@testable import SBJStructuredAI

@Suite("Native dynamic read schemas (no inference)")
struct SBJAISchemaBuilderTests {
    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func completeTypeAndInstanceSchema() throws {
        let fixture = SBJSemanticReadFixture()
        let definition = try SBJAISchemaBuilder.dynamicSchema(for: fixture)
        #expect(!definition.dependencies.isEmpty)
        _ = try definition.generationSchema() // Native resolution and validation.
        let context = try SBJAISchemaBuilder.prepare(for: fixture)
        let model = context.documentDescription
        let query = context.snapshot.paths
        for marker in ["Experience level", "Character level", "Used for level-dependent calculations", "Range 1–20",
                       "Allowed values: Alpha, Beta", "Pattern: [A-Za-z]+", "Measurement minimum", "kilogram", "neverInstantiatedField",
                       "Absent type information", "inactive", "doubled", "fixed", "$/items/0", "Same", "key:a~1b~0c"] {
            #expect(model.contains(marker), "Missing model schema marker: \(marker)")
        }
        _ = context.readParameters // Resolved native schema; no serialization.
        #expect(!model.contains("Current experience tier."))
        #expect(!model.contains("TEST ACCESSIBILITY LABEL"))
        #expect(!model.contains("TEST ACCESSIBILITY HINT"))
        #expect(!model.contains("hiddenItem"))
        #expect(!model.contains("HIDDEN ROOT VALUE"))
        #expect(!query.contains("$/absent/neverInstantiatedField"))
        #expect(!query.contains("$/inactiveChoice/payload"))
        #expect(!context.instructions.contains(model))
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func nativeToolArgumentsReadExactValues() async throws {
        let context = try SBJAISchemaBuilder.prepare(for: SBJSemanticReadFixture())
        let tool = SBJAIReadTool(context: context)
        let arguments = GeneratedContent(properties: ["operation": "read", "paths": ["$/level", "$/lookup/key:a~1b~0c/value"]])
        let output = try await tool.call(arguments: arguments)
        let rows = try output.value([GeneratedContent].self)
        #expect(try rows[0].value(Int.self, forProperty: "value") == 9)
        #expect(try rows[1].value(Int.self, forProperty: "value") == 23)
        let invalid = GeneratedContent(properties: ["operation": "read", "paths": ["$/hidden"]])
        let failure = try await tool.call(arguments: invalid)
        #expect(try failure.value(String.self, forProperty: "error").contains("No such access path"))
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func nativeFindUsesAliases() async throws {
        let context = try SBJAISchemaBuilder.prepare(for: SBJSemanticReadFixture())
        let tool = SBJAIReadTool(context: context)
        let arguments = GeneratedContent(properties: ["operation": "find", "query": "Character level"])
        let output = try await tool.call(arguments: arguments)
        let rows = try output.value([GeneratedContent].self, forProperty: "matches")
        #expect(try rows.first?.value(String.self, forProperty: "path") == "$/level")
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func querySchemaTokenCostDoesNotGrowWithInstanceSize() async throws {
        let model = SystemLanguageModel.default
        guard model.isAvailable else { return }
        var fixture = SBJSemanticReadFixture()
        let small = try SBJAISchemaBuilder.prepare(for: fixture)
        fixture.items = Array(repeating: SBJSemanticReadFixtureItem(name: "Repeated", rank: 7), count: 120)
        let large = try SBJAISchemaBuilder.prepare(for: fixture)
        #expect(large.snapshot.paths.count > small.snapshot.paths.count)
        let smallTokens = try await model.tokenCount(for: small.readParameters)
        let largeTokens = try await model.tokenCount(for: large.readParameters)
        #expect(smallTokens == largeTokens)
        let documentTokens = try await model.tokenCount(for: small.documentSchema)
        #expect(documentTokens > smallTokens)
    }

    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func nativeContentPreservesNullAndExactNumericText() throws {
        let value: SBJSemanticValue = .object([
            "missing": .null, "empty": .array([]), "flag": .bool(true),
            "unsigned": .unsigned(.max), "decimal": .decimal(Decimal(string: "1234567890.123456789")!)
        ])
        let content = value.nativeContent
        guard case .structure(let properties, _) = content.kind else {
            Issue.record("Expected structured content")
            return
        }
        let missing = try #require(properties["missing"])
        guard case .null = missing.kind else { Issue.record("Expected native null"); return }
        #expect(try content.value([GeneratedContent].self, forProperty: "empty").isEmpty)
        #expect(try content.value(Bool.self, forProperty: "flag"))
        #expect(try content.value(String.self, forProperty: "unsigned") == "18446744073709551615")
        #expect(try content.value(String.self, forProperty: "decimal") == "1234567890.123456789")
    }

    #if DEBUG
    @available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
    @Test func entireCanonicalSampleSchema() throws {
        let context = try SBJAISchemaBuilder.prepare(for: SBJStructureSampleModel())
        #expect(context.documentDescription.contains("Breakfast, lunch, dinner, or dessert."))
        #expect(!context.documentDescription.contains("The meal category for a recipe."))
        #expect(!context.documentDescription.contains("Choose the meal category"))
        #expect(context.documentDescription.contains("SBJStructureSampleCookingInstruction"))
        #expect(context.documentDescription.contains("Red bell pepper"))
        #expect(context.snapshot.paths.contains("$/ingredients/0/quantity"))
        #expect(!context.snapshot.paths.contains("$/importSource"))
    }
    #endif
}
#endif
