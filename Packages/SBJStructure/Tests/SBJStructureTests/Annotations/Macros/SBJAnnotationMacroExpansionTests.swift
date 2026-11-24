import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import SBJStructureMacros

final class SBJAnnotationMacroExpansionTests: XCTestCase {
    private let macros: [String: Macro.Type] = [
        "SBJStructureExtension": SBJStructureExtensionMacro.self,
        "SBJNomenclatureEnum": SBJNomenclatureMacro.self,
        "SBJDesignatedInit": SBJDesignatedInitMacro.self,
        "SBJAutoNomenclature": SBJAutoNomenclatureMacro.self,
    ]

    func testAutoNomenclatureDerivesTitleInAnnotatedExtension() {
        assertMacroExpansion(
            """
            extension Example {
                static let hitPointsNomenclature = #SBJAutoNomenclature(summary: "Current health")
            }
            """,
            expandedSource: """
            extension Example {
                static let hitPointsNomenclature = SBJNomenclature(title: "Hit Points", summary: "Current health")
            }
            """,
            macros: macros
        )
    }

    func testAutoNomenclatureMultipleArgumentsDoNotDuplicateCommas() {
        assertMacroExpansion(
            """
            extension Example {
                static let servingsNomenclature = #SBJAutoNomenclature(
                    summary: "Portion count",
                    details: "Between 1 and 24",
                    aliases: ["Portions", "Servings"],
                    accessibilityLabel: "Recipe servings",
                    accessibilityHint: "Enter portions"
                )
            }
            """,
            expandedSource: """
            extension Example {
                static let servingsNomenclature = SBJNomenclature(title: "Servings", summary: "Portion count", details: "Between 1 and 24", aliases: ["Portions", "Servings"], accessibilityLabel: "Recipe servings", accessibilityHint: "Enter portions")
            }
            """,
            macros: macros
        )
    }

    func testExtensionNomenclatureDiscoversStaticLetAndComputedVar() {
        assertMacroExpansion(
            """
            @SBJStructureExtension
            extension Example {
                public static let nameNomenclature = SBJNomenclature(
                	summary: "Name"
                )
                static var ageNomenclature: SBJNomenclature {
                    get { SBJNomenclature(summary: "Age") }
                }
            }
            """,
            expandedSource: """
            extension Example {
                public static let nameNomenclature = SBJNomenclature(
                	summary: "Name"
                )
                static var ageNomenclature: SBJNomenclature {
                    get { SBJNomenclature(summary: "Age") }
                }

                public static func _extensionNomenclature<Value>(for keyPath: KeyPath<Example, Value>) -> SBJNomenclature? {
                    if keyPath == \\Example.name {
                        return Self.nameNomenclature
                    }
                    if keyPath == \\Example.age {
                        return Self.ageNomenclature
                    }
                    return Self._nomenclature(for: keyPath)
                }

                public static func propertyNomenclature<Value>(for keyPath: KeyPath<Example, Value>) -> SBJNomenclature? {
                    SBJNomenclatureResolver.resolve(_extensionNomenclature(for: keyPath), for: Value.self)
                }
            }
            """,
            macros: macros
        )
    }

    func testExtensionNomenclatureSupportsExplicitPublicOverride() {
        assertMacroExpansion(
            """
            @SBJStructureExtension
            extension Example {
                public static let nameNomenclature = SBJNomenclature(
                	summary: "Name"
                )
                static func propertyNomenclature<Value>(for keyPath: KeyPath<Example, Value>) -> SBJNomenclature? {
                    _extensionNomenclature(for: keyPath)
                }
            }
            """,
            expandedSource: """
            extension Example {
                public static let nameNomenclature = SBJNomenclature(
                	summary: "Name"
                )
                static func propertyNomenclature<Value>(for keyPath: KeyPath<Example, Value>) -> SBJNomenclature? {
                    _extensionNomenclature(for: keyPath)
                }

                public static func _extensionNomenclature<Value>(for keyPath: KeyPath<Example, Value>) -> SBJNomenclature? {
                    if keyPath == \\Example.name {
                        return Self.nameNomenclature
                    }
                    return Self._nomenclature(for: keyPath)
                }
            }
            """,
            macros: macros
        )
    }

    func testPreferredInitCapturesExternalLabelsAndLocalPropertyNames() {
        assertMacroExpansion(
            """
            struct FontLike {
                @SBJDesignatedInit
                init(_ name: String?, ofSize size: Double, weight: Int) {}
            }
            """,
            expandedSource: """
            struct FontLike {
                init(_ name: String?, ofSize size: Double, weight: Int) {}

                public static var sbjSwiftInitializerParameters: [SBJSwiftInitializerParameter] {
                    [
                        .init(propertyName: "name", label: nil),
                        .init(propertyName: "size", label: "ofSize"),
                        .init(propertyName: "weight", label: "weight")
                    ]
                }
            }
            """,
            macros: macros
        )
    }


    func testPreferredInitMapsParameterToDirectlyAssignedProperty() {
        assertMacroExpansion(
            """
            struct TitledBodyLike {
                @SBJDesignatedInit
                init(_ key: String, _ body: String) {
                    self.title = key
                    self.body = body
                }
            }
            """,
            expandedSource: """
            struct TitledBodyLike {
                init(_ key: String, _ body: String) {
                    self.title = key
                    self.body = body
                }

                public static var sbjSwiftInitializerParameters: [SBJSwiftInitializerParameter] {
                    [
                        .init(propertyName: "title", label: nil),
                        .init(propertyName: "body", label: nil)
                    ]
                }
            }
            """,
            macros: macros
        )
    }


    func testDesignatedInitCapturesDefaultExpressions() {
        assertMacroExpansion(
            """
            struct SectionLike {
                @SBJDesignatedInit
                init(_ name: String = "", _ values: [String] = []) {}
            }
            """,
            expandedSource: #"""
            struct SectionLike {
                init(_ name: String = "", _ values: [String] = []) {}

                public static var sbjSwiftInitializerParameters: [SBJSwiftInitializerParameter] {
                    [
                        .init(propertyName: "name", label: nil, defaultExpression: "\"\""),
                        .init(propertyName: "values", label: nil, defaultExpression: "[]")
                    ]
                }
            }
            """#,
            macros: macros
        )
    }
    func testPreferredInitMapsMultilineDirectAssignment() {
        assertMacroExpansion(
            """
            struct Example {
                @SBJDesignatedInit
                init(_ amount: Double) {
                    self.value =
                        amount
                }
            }
            """,
            expandedSource: """
            struct Example {
                init(_ amount: Double) {
                    self.value =
                        amount
                }

                public static var sbjSwiftInitializerParameters: [SBJSwiftInitializerParameter] {
                    [
                        .init(propertyName: "value", label: nil)
                    ]
                }
            }
            """,
            macros: macros
        )
    }

}
