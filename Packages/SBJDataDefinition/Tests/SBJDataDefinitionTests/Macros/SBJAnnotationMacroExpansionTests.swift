import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import SBJDataDefinitionMacros

final class SBJAnnotationMacroExpansionTests: XCTestCase {
    private let macros: [String: Macro.Type] = [
        "SBJPropertyInfo": SBJPropertyInfoMacro.self,
        "SBJPropertyInfoEnum": SBJPropertyInfoMacro.self,
        "SBJDesignatedInit": SBJDesignatedInitMacro.self,
    ]

    func testExtensionPropertyInfoDiscoversStaticLetAndComputedVar() {
        assertMacroExpansion(
            """
            @SBJPropertyInfo
            extension Example {
                static let nameInfo = SBJPropertyInfo(summary: "Name")
                static var ageInfo: SBJPropertyInfo {
                    get { SBJPropertyInfo(summary: "Age") }
                }
            }
            """,
            expandedSource: """
            extension Example {
                static let nameInfo = SBJPropertyInfo(summary: "Name")
                static var ageInfo: SBJPropertyInfo {
                    get { SBJPropertyInfo(summary: "Age") }
                }

                public static func _extensionPropertyInfo<Value>(for keyPath: KeyPath<Example, Value>) -> SBJPropertyInfo? {
                    if keyPath == \\Example.name {
                        return Self.nameInfo
                    }
                    if keyPath == \\Example.age {
                        return Self.ageInfo
                    }
                    return Self._propertyInfo(for: keyPath)
                }

                public static func propertyInfo<Value>(for keyPath: KeyPath<Example, Value>) -> SBJPropertyInfo? {
                    _extensionPropertyInfo(for: keyPath)
                }
            }
            """,
            macros: macros
        )
    }

    func testExtensionPropertyInfoSupportsExplicitPublicOverride() {
        assertMacroExpansion(
            """
            @SBJPropertyInfo
            extension Example {
                static let nameInfo = SBJPropertyInfo(summary: "Name")
                static func propertyInfo<Value>(for keyPath: KeyPath<Example, Value>) -> SBJPropertyInfo? {
                    _extensionPropertyInfo(for: keyPath)
                }
            }
            """,
            expandedSource: """
            extension Example {
                static let nameInfo = SBJPropertyInfo(summary: "Name")
                static func propertyInfo<Value>(for keyPath: KeyPath<Example, Value>) -> SBJPropertyInfo? {
                    _extensionPropertyInfo(for: keyPath)
                }

                public static func _extensionPropertyInfo<Value>(for keyPath: KeyPath<Example, Value>) -> SBJPropertyInfo? {
                    if keyPath == \\Example.name {
                        return Self.nameInfo
                    }
                    return Self._propertyInfo(for: keyPath)
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
}
