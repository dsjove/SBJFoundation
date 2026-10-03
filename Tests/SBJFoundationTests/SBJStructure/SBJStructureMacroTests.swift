import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
@testable import SBJFoundationMacros

final class SBJStructureMacroTests: XCTestCase {
    private let macros: [String: Macro.Type] = [
        "SBJStructure": SBJStructureMacro.self,
        "SBJDesignatedInit": SBJDesignatedInitMacro.self,
        "SBJNotEditable": SBJNotEditableMacro.self,
        "SBJEditorProperty": SBJEditorPropertyMacro.self,
        "SBJString": SBJStringMacro.self,
        "SBJPresentation": SBJPresentationMacro.self,
        "SBJInteger": SBJIntegerMacro.self,
        "SBJNumber": SBJNumberMacro.self,
        "SBJOptional": SBJOptionalMacro.self,
        "SBJArray": SBJArrayMacro.self,
        "SBJSet": SBJSetMacro.self,
        "SBJDictionary": SBJDictionaryMacro.self,
        "SBJURL": SBJURLMacro.self,
        "SBJUUID": SBJUUIDMacro.self,
        "SBJDate": SBJDateMacro.self,
        "SBJData": SBJDataMacro.self,
        "SBJColor": SBJColorMacro.self,
    ]


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

    func testEmptyStructureGeneratesPublicConsumptionHooksAndEditorConformance() {
        assertMacroExpansion(
            """
            @SBJStructure
            struct Empty {}
            """,
            expandedSource: """
            struct Empty {

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [

                    ]
                }

                static var sbjEditableFields: [SBJEditableField<Self>] {
                    [

                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [

                    ]
                }

                var _hasContent: Bool {
                    true
                }

                var hasContent: Bool {
                    _hasContent
                }

                func _invariant(at keyPath: SBJValidationKeyPath) throws {

                }

                func invariant(at keyPath: SBJValidationKeyPath) throws {
                    try _invariant(at: keyPath)
                }

                func _sbjStructuralEquals(_ other: Self) -> Bool {
                    true
                }

                func sbjStructuralEquals(_ other: Self) -> Bool {
                    _sbjStructuralEquals(other)
                }

                static func sbjDefaultValue() -> Self? {
                    .init()
                }
            }

            extension Empty: SBJEditable, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }

    func testAnnotatedStoredPropertyRemainsStoredProperty() {
        assertMacroExpansion(
            """
            @SBJStructure
            struct Model {
                @SBJString(minLength: 1, maxLength: 40)
                var displayName: String
            }
            """,
            expandedSource: """
            struct Model {
                var displayName: String

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "displayName", displayName: "displayName".uncamelCased, keyPath: \\Self.displayName, kind: .text, constraints: [.textLength(min: 1, max: 40)], hints: [], info: Self.propertyInfo(for: \\Self.displayName))
                    ]
                }

                static var sbjEditableFields: [SBJEditableField<Self>] {
                    [
                        SBJEditableField<Self>(name: "displayName".uncamelCased, \\.displayName)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "displayName".uncamelCased, \\.displayName)
                    ]
                }

                var _hasContent: Bool {
                    SBJContentCheck.hasContent(displayName)
                }

                var hasContent: Bool {
                    _hasContent
                }

                func _invariant(at keyPath: SBJValidationKeyPath) throws {
                    try SBJInvariantCheck.validate(displayName, at: keyPath.appending(\\Self.displayName))
                    try SBJInvariantCheck.requireText(displayName, minLength: 1, maxLength: 40, at: keyPath.appending(\\Self.displayName))
                }

                func invariant(at keyPath: SBJValidationKeyPath) throws {
                    try _invariant(at: keyPath)
                }

                func _sbjStructuralEquals(_ other: Self) -> Bool {
                    SBJStructuralCompare.equals(self.displayName, other.displayName)
                }

                func sbjStructuralEquals(_ other: Self) -> Bool {
                    _sbjStructuralEquals(other)
                }
            }

            extension Model: SBJEditable, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }

    func testEditorPropertyGeneratesOnlyEditorField() {
        assertMacroExpansion(
            """
            @SBJStructure
            struct Model {
                var stored: String

                @SBJEditorProperty
                var image: PlatformImage? {
                    get { nil }
                    set {}
                }
            }
            """,
            expandedSource: """
            struct Model {
                var stored: String
                var image: PlatformImage? {
                    get { nil }
                    set {}
                }

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "stored", displayName: "stored".uncamelCased, keyPath: \\Self.stored, kind: .text, constraints: [], hints: [], info: Self.propertyInfo(for: \\Self.stored))
                    ]
                }

                static var sbjEditableFields: [SBJEditableField<Self>] {
                    [
                        SBJEditableField<Self>(name: "stored".uncamelCased, \\.stored),
                        SBJEditableField<Self>(editorOnlyName: "image".uncamelCased, \\.image)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "stored".uncamelCased, \\.stored),
                        SBJEditorPropertyDescriptor<Self>(editorOnlyName: "image".uncamelCased, \\.image)
                    ]
                }

                var _hasContent: Bool {
                    SBJContentCheck.hasContent(stored)
                }

                var hasContent: Bool {
                    _hasContent
                }

                func _invariant(at keyPath: SBJValidationKeyPath) throws {
                    try SBJInvariantCheck.validate(stored, at: keyPath.appending(\\Self.stored))
                }

                func invariant(at keyPath: SBJValidationKeyPath) throws {
                    try _invariant(at: keyPath)
                }

                func _sbjStructuralEquals(_ other: Self) -> Bool {
                    SBJStructuralCompare.equals(self.stored, other.stored)
                }

                func sbjStructuralEquals(_ other: Self) -> Bool {
                    _sbjStructuralEquals(other)
                }
            }

            extension Model: SBJEditable, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }

    func testCustomPublicHooksCanExtendGeneratedUnderscoreBehavior() {
        assertMacroExpansion(
            """
            @SBJStructure
            struct Model {
                var value: String

                var hasContent: Bool {
                    _hasContent && value != "ignored"
                }

                func invariant(at keyPath: SBJValidationKeyPath) throws {
                    try _invariant(at: keyPath)
                    try SBJInvariantCheck.require(value != "reserved", at: keyPath, "reserved")
                }
            }
            """,
            expandedSource: """
            struct Model {
                var value: String

                var hasContent: Bool {
                    _hasContent && value != "ignored"
                }

                func invariant(at keyPath: SBJValidationKeyPath) throws {
                    try _invariant(at: keyPath)
                    try SBJInvariantCheck.require(value != "reserved", at: keyPath, "reserved")
                }

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "value", displayName: "value".uncamelCased, keyPath: \\Self.value, kind: .text, constraints: [], hints: [], info: Self.propertyInfo(for: \\Self.value))
                    ]
                }

                static var sbjEditableFields: [SBJEditableField<Self>] {
                    [
                        SBJEditableField<Self>(name: "value".uncamelCased, \\.value)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "value".uncamelCased, \\.value)
                    ]
                }

                var _hasContent: Bool {
                    SBJContentCheck.hasContent(value)
                }

                func _invariant(at keyPath: SBJValidationKeyPath) throws {
                    try SBJInvariantCheck.validate(value, at: keyPath.appending(\\Self.value))
                }

                func _sbjStructuralEquals(_ other: Self) -> Bool {
                    SBJStructuralCompare.equals(self.value, other.value)
                }

                func sbjStructuralEquals(_ other: Self) -> Bool {
                    _sbjStructuralEquals(other)
                }
            }

            extension Model: SBJEditable, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }

    func testNotEditableStillParticipatesInStructureButNotEditorFields() {
        assertMacroExpansion(
            """
            @SBJStructure
            struct Model {
                @SBJNotEditable
                let identifier: String
            }
            """,
            expandedSource: """
            struct Model {
                let identifier: String

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "identifier", displayName: "identifier".uncamelCased, keyPath: \\Self.identifier, kind: .text, constraints: [], hints: [], info: Self.propertyInfo(for: \\Self.identifier))
                    ]
                }

                static var sbjEditableFields: [SBJEditableField<Self>] {
                    [

                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [

                    ]
                }

                var _hasContent: Bool {
                    SBJContentCheck.hasContent(identifier)
                }

                var hasContent: Bool {
                    _hasContent
                }

                func _invariant(at keyPath: SBJValidationKeyPath) throws {
                    try SBJInvariantCheck.validate(identifier, at: keyPath.appending(\\Self.identifier))
                }

                func invariant(at keyPath: SBJValidationKeyPath) throws {
                    try _invariant(at: keyPath)
                }

                func _sbjStructuralEquals(_ other: Self) -> Bool {
                    SBJStructuralCompare.equals(self.identifier, other.identifier)
                }

                func sbjStructuralEquals(_ other: Self) -> Bool {
                    _sbjStructuralEquals(other)
                }
            }

            extension Model: SBJEditable, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }

    func testUniqueByPreservesTypedKeyPathAndEscapesDescriptiveMetadata() {
        assertMacroExpansion(
            """
            @SBJStructure
            struct Model {
                @SBJArray(uniqueBy: \\Item.id)
                var items: [Item]
            }
            """,
            expandedSource: """
            struct Model {
                var items: [Item]

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "items", displayName: "items".uncamelCased, keyPath: \\Self.items, kind: .array, constraints: [.uniqueBy("\\\\Item.id")], hints: [.reorderable(true)], info: Self.propertyInfo(for: \\Self.items))
                    ]
                }

                static var sbjEditableFields: [SBJEditableField<Self>] {
                    [
                        SBJEditableField<Self>(name: "items".uncamelCased, \\.items)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "items".uncamelCased, \\.items)
                    ]
                }

                var _hasContent: Bool {
                    SBJContentCheck.hasContent(items)
                }

                var hasContent: Bool {
                    _hasContent
                }

                func _invariant(at keyPath: SBJValidationKeyPath) throws {
                    try SBJInvariantCheck.validate(items, at: keyPath.appending(\\Self.items))
                    try SBJInvariantCheck.requireUnique(items, by: \\Item.id, at: keyPath.appending(\\Self.items))
                }

                func invariant(at keyPath: SBJValidationKeyPath) throws {
                    try _invariant(at: keyPath)
                }

                func _sbjStructuralEquals(_ other: Self) -> Bool {
                    SBJStructuralCompare.equals(self.items, other.items)
                }

                func sbjStructuralEquals(_ other: Self) -> Bool {
                    _sbjStructuralEquals(other)
                }
            }

            extension Model: SBJEditable, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }

    func testConflictingArrayUniquenessProducesDiagnostic() {
        assertMacroExpansion(
            """
            @SBJStructure
            struct Model {
                @SBJArray(unique: true, uniqueBy: \\Item.id)
                var items: [Item]
            }
            """,
            expandedSource: """
            struct Model {
                var items: [Item]

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "items", displayName: "items".uncamelCased, keyPath: \\Self.items, kind: .array, constraints: [.uniqueBy("\\\\Item.id")], hints: [.reorderable(true)], info: Self.propertyInfo(for: \\Self.items))
                    ]
                }

                static var sbjEditableFields: [SBJEditableField<Self>] {
                    [
                        SBJEditableField<Self>(name: "items".uncamelCased, \\.items)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "items".uncamelCased, \\.items)
                    ]
                }

                var _hasContent: Bool {
                    SBJContentCheck.hasContent(items)
                }

                var hasContent: Bool {
                    _hasContent
                }

                func _invariant(at keyPath: SBJValidationKeyPath) throws {
                    try SBJInvariantCheck.validate(items, at: keyPath.appending(\\Self.items))
                    try SBJInvariantCheck.requireUnique(items, by: \\Item.id, at: keyPath.appending(\\Self.items))
                }

                func invariant(at keyPath: SBJValidationKeyPath) throws {
                    try _invariant(at: keyPath)
                }

                func _sbjStructuralEquals(_ other: Self) -> Bool {
                    SBJStructuralCompare.equals(self.items, other.items)
                }

                func sbjStructuralEquals(_ other: Self) -> Bool {
                    _sbjStructuralEquals(other)
                }
            }

            extension Model: SBJEditable, SBJSwiftUIEditable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "Array property 'items' cannot declare both unique: true and uniqueBy; choose one uniqueness rule",
                    line: 4,
                    column: 9
                )
            ],
            macros: macros
        )
    }

    func testImmutablePropertyIsSimplyNotEditable() {
        assertMacroExpansion(
            """
            @SBJStructure
            struct Model {
                let identifier: String
            }
            """,
            expandedSource: """
            struct Model {
                let identifier: String

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "identifier", displayName: "identifier".uncamelCased, keyPath: \\Self.identifier, kind: .text, constraints: [], hints: [], info: Self.propertyInfo(for: \\Self.identifier))
                    ]
                }

                static var sbjEditableFields: [SBJEditableField<Self>] {
                    [

                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [

                    ]
                }

                var _hasContent: Bool {
                    SBJContentCheck.hasContent(identifier)
                }

                var hasContent: Bool {
                    _hasContent
                }

                func _invariant(at keyPath: SBJValidationKeyPath) throws {
                    try SBJInvariantCheck.validate(identifier, at: keyPath.appending(\\Self.identifier))
                }

                func invariant(at keyPath: SBJValidationKeyPath) throws {
                    try _invariant(at: keyPath)
                }

                func _sbjStructuralEquals(_ other: Self) -> Bool {
                    SBJStructuralCompare.equals(self.identifier, other.identifier)
                }

                func sbjStructuralEquals(_ other: Self) -> Bool {
                    _sbjStructuralEquals(other)
                }
            }

            extension Model: SBJEditable, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }
    func testCodingKeysDefineMembershipAndUnannotatedTypesInferKinds() {
        assertMacroExpansion(
            """
            @SBJStructure
            struct Model {
                var name: String
                var website: URL
                var ignored: Int

                enum CodingKeys: String, CodingKey {
                    case name
                    case website
                }
            }
            """,
            expandedSource: """
            struct Model {
                var name: String
                var website: URL
                var ignored: Int

                enum CodingKeys: String, CodingKey {
                    case name
                    case website
                }

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "name", displayName: "name".uncamelCased, keyPath: \\Self.name, kind: .text, constraints: [], hints: [], info: Self.propertyInfo(for: \\Self.name)),
                        SBJPropertyMetadata<Self>(sourceName: "website", displayName: "website".uncamelCased, keyPath: \\Self.website, kind: .url, constraints: [], hints: [], info: Self.propertyInfo(for: \\Self.website))
                    ]
                }

                static var sbjEditableFields: [SBJEditableField<Self>] {
                    [
                        SBJEditableField<Self>(name: "name".uncamelCased, \\.name),
                        SBJEditableField<Self>(name: "website".uncamelCased, \\.website)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "name".uncamelCased, \\.name),
                        SBJEditorPropertyDescriptor<Self>(name: "website".uncamelCased, \\.website)
                    ]
                }

                var _hasContent: Bool {
                    SBJContentCheck.hasContent(name) ||
                    SBJContentCheck.hasContent(website)
                }

                var hasContent: Bool {
                    _hasContent
                }

                func _invariant(at keyPath: SBJValidationKeyPath) throws {
                    try SBJInvariantCheck.validate(name, at: keyPath.appending(\\Self.name))
                    try SBJInvariantCheck.validate(website, at: keyPath.appending(\\Self.website))
                }

                func invariant(at keyPath: SBJValidationKeyPath) throws {
                    try _invariant(at: keyPath)
                }

                func _sbjStructuralEquals(_ other: Self) -> Bool {
                    SBJStructuralCompare.equals(self.name, other.name) &&
                    SBJStructuralCompare.equals(self.website, other.website)
                }

                func sbjStructuralEquals(_ other: Self) -> Bool {
                    _sbjStructuralEquals(other)
                }
            }

            extension Model: SBJEditable, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }

    func testScalarAnnotationsAddRulesAndHintsRatherThanMembership() {
        assertMacroExpansion(
            """
            @SBJStructure
            struct Model {
                @SBJUUID(nonzero: true)
                var identifier: UUID
                @SBJDate(range: Date.distantPast ... Date.distantFuture)
                var created: Date
                @SBJURL(allowed: [.network])
                var website: URL
                @SBJColor(alpha: false)
                var color: CodableColor
            }
            """,
            expandedSource: """
            struct Model {
                var identifier: UUID
                var created: Date
                var website: URL
                var color: CodableColor

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "identifier", displayName: "identifier".uncamelCased, keyPath: \\Self.identifier, kind: .uuid, constraints: [.uuidNonzero], hints: [], info: Self.propertyInfo(for: \\Self.identifier)),
                        SBJPropertyMetadata<Self>(sourceName: "created", displayName: "created".uncamelCased, keyPath: \\Self.created, kind: .date, constraints: [.dateRange(Date.distantPast ... Date.distantFuture)], hints: [], info: Self.propertyInfo(for: \\Self.created)),
                        SBJPropertyMetadata<Self>(sourceName: "website", displayName: "website".uncamelCased, keyPath: \\Self.website, kind: .url, constraints: [.urlKinds([.network])], hints: [], info: Self.propertyInfo(for: \\Self.website)),
                        SBJPropertyMetadata<Self>(sourceName: "color", displayName: "color".uncamelCased, keyPath: \\Self.color, kind: .color, constraints: [], hints: [.colorSupportsAlpha(false)], info: Self.propertyInfo(for: \\Self.color))
                    ]
                }

                static var sbjEditableFields: [SBJEditableField<Self>] {
                    [
                        SBJEditableField<Self>(name: "identifier".uncamelCased, \\.identifier),
                        SBJEditableField<Self>(name: "created".uncamelCased, \\.created),
                        SBJEditableField<Self>(name: "website".uncamelCased, \\.website),
                        SBJEditableField<Self>(name: "color".uncamelCased, \\.color)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "identifier".uncamelCased, \\.identifier),
                        SBJEditorPropertyDescriptor<Self>(name: "created".uncamelCased, \\.created),
                        SBJEditorPropertyDescriptor<Self>(name: "website".uncamelCased, \\.website),
                        SBJEditorPropertyDescriptor<Self>(name: "color".uncamelCased, \\.color)
                    ]
                }

                var _hasContent: Bool {
                    SBJContentCheck.hasContent(identifier) ||
                    SBJContentCheck.hasContent(created) ||
                    SBJContentCheck.hasContent(website) ||
                    SBJContentCheck.hasContent(color)
                }

                var hasContent: Bool {
                    _hasContent
                }

                func _invariant(at keyPath: SBJValidationKeyPath) throws {
                    try SBJInvariantCheck.validate(identifier, at: keyPath.appending(\\Self.identifier))
                    try SBJInvariantCheck.requireNonzero(identifier, at: keyPath.appending(\\Self.identifier))
                    try SBJInvariantCheck.validate(created, at: keyPath.appending(\\Self.created))
                    try SBJInvariantCheck.requireRange(created, Date.distantPast ... Date.distantFuture, at: keyPath.appending(\\Self.created))
                    try SBJInvariantCheck.validate(website, at: keyPath.appending(\\Self.website))
                    try SBJInvariantCheck.requireURL(website, allowed: [.network], at: keyPath.appending(\\Self.website))
                    try SBJInvariantCheck.validate(color, at: keyPath.appending(\\Self.color))
                }

                func invariant(at keyPath: SBJValidationKeyPath) throws {
                    try _invariant(at: keyPath)
                }

                func _sbjStructuralEquals(_ other: Self) -> Bool {
                    SBJStructuralCompare.equals(self.identifier, other.identifier) &&
                    SBJStructuralCompare.equals(self.created, other.created) &&
                    SBJStructuralCompare.equals(self.website, other.website) &&
                    SBJStructuralCompare.equals(self.color, other.color)
                }

                func sbjStructuralEquals(_ other: Self) -> Bool {
                    _sbjStructuralEquals(other)
                }
            }

            extension Model: SBJEditable, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }

    func testCodableStructWithDefaultableInitializationSynthesizesDefaultValue() {
        assertMacroExpansion(
            """
            @SBJStructure
            struct Defaultable: Codable {
                var name: String = ""
            }
            """,
            expandedSource: """
            struct Defaultable: Codable {
                var name: String = ""

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "name", displayName: "name".uncamelCased, keyPath: \\Self.name, kind: .text, constraints: [], hints: [], info: Self.propertyInfo(for: \\Self.name))
                    ]
                }

                static var sbjEditableFields: [SBJEditableField<Self>] {
                    [
                        SBJEditableField<Self>(name: "name".uncamelCased, \\.name)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "name".uncamelCased, \\.name)
                    ]
                }

                var _hasContent: Bool {
                    SBJContentCheck.hasContent(name)
                }

                var hasContent: Bool {
                    _hasContent
                }

                func _invariant(at keyPath: SBJValidationKeyPath) throws {
                    try SBJInvariantCheck.validate(name, at: keyPath.appending(\\Self.name))
                }

                func invariant(at keyPath: SBJValidationKeyPath) throws {
                    try _invariant(at: keyPath)
                }

                func _sbjStructuralEquals(_ other: Self) -> Bool {
                    SBJStructuralCompare.equals(self.name, other.name)
                }

                func sbjStructuralEquals(_ other: Self) -> Bool {
                    _sbjStructuralEquals(other)
                }

                static func sbjDefaultValue() -> Self? {
                    .init()
                }
            }

            extension Defaultable: SBJEditable, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }


    func testInheritedCodableProtocolStillSynthesizesDefaultValue() {
        assertMacroExpansion(
            """
            protocol ModelCodable: Codable {}

            @SBJStructure
            struct Model: ModelCodable {
                var name = ""
            }
            """,
            expandedSource: """
            protocol ModelCodable: Codable {}
            struct Model: ModelCodable {
                var name = ""

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "name", displayName: "name".uncamelCased, keyPath: \\Self.name, kind: .text, constraints: [], hints: [], info: Self.propertyInfo(for: \\Self.name))
                    ]
                }

                static var sbjEditableFields: [SBJEditableField<Self>] {
                    [
                        SBJEditableField<Self>(name: "name".uncamelCased, \\.name)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "name".uncamelCased, \\.name)
                    ]
                }

                var _hasContent: Bool {
                    SBJContentCheck.hasContent(name)
                }

                var hasContent: Bool {
                    _hasContent
                }

                func _invariant(at keyPath: SBJValidationKeyPath) throws {
                    try SBJInvariantCheck.validate(name, at: keyPath.appending(\\Self.name))
                }

                func invariant(at keyPath: SBJValidationKeyPath) throws {
                    try _invariant(at: keyPath)
                }

                func _sbjStructuralEquals(_ other: Self) -> Bool {
                    SBJStructuralCompare.equals(self.name, other.name)
                }

                func sbjStructuralEquals(_ other: Self) -> Bool {
                    _sbjStructuralEquals(other)
                }

                static func sbjDefaultValue() -> Self? {
                    .init()
                }
            }

            extension Model: SBJEditable, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }

    func testAnnotationTypeMismatchProducesDiagnostic() {
        assertMacroExpansion(
            """
            @SBJStructure
            struct Model {
                @SBJData
                var payload: String
            }
            """,
            expandedSource: """
            struct Model {
                var payload: String

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "payload", displayName: "payload".uncamelCased, keyPath: \\Self.payload, kind: .text, constraints: [], hints: [], info: Self.propertyInfo(for: \\Self.payload))
                    ]
                }

                static var sbjEditableFields: [SBJEditableField<Self>] {
                    [
                        SBJEditableField<Self>(name: "payload".uncamelCased, \\.payload)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "payload".uncamelCased, \\.payload)
                    ]
                }

                var _hasContent: Bool {
                    SBJContentCheck.hasContent(payload)
                }

                var hasContent: Bool {
                    _hasContent
                }

                func _invariant(at keyPath: SBJValidationKeyPath) throws {
                    try SBJInvariantCheck.validate(payload, at: keyPath.appending(\\Self.payload))
                }

                func invariant(at keyPath: SBJValidationKeyPath) throws {
                    try _invariant(at: keyPath)
                }

                func _sbjStructuralEquals(_ other: Self) -> Bool {
                    SBJStructuralCompare.equals(self.payload, other.payload)
                }

                func sbjStructuralEquals(_ other: Self) -> Bool {
                    _sbjStructuralEquals(other)
                }
            }

            extension Model: SBJEditable, SBJSwiftUIEditable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@SBJData on property 'payload' requires Data or Data?; found 'String'",
                    line: 4,
                    column: 9,
                    severity: .error
                )
            ],
            macros: macros
        )
    }

    func testInvalidDataDeclarationProducesDiagnostics() {
        assertMacroExpansion(
            """
            @SBJStructure
            struct Model {
                @SBJData(min: 8, max: 4, modulo: 0)
                var payload: Data
            }
            """,
            expandedSource: """
            struct Model {
                var payload: Data

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "payload", displayName: "payload".uncamelCased, keyPath: \\Self.payload, kind: .data, constraints: [.dataSize(min: 8, max: 4, modulo: 0)], hints: [], info: Self.propertyInfo(for: \\Self.payload))
                    ]
                }

                static var sbjEditableFields: [SBJEditableField<Self>] {
                    [
                        SBJEditableField<Self>(name: "payload".uncamelCased, \\.payload)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "payload".uncamelCased, \\.payload)
                    ]
                }

                var _hasContent: Bool {
                    SBJContentCheck.hasContent(payload)
                }

                var hasContent: Bool {
                    _hasContent
                }

                func _invariant(at keyPath: SBJValidationKeyPath) throws {
                    try SBJInvariantCheck.validate(payload, at: keyPath.appending(\\Self.payload))
                    try SBJInvariantCheck.requireData(payload, min: 8, max: 4, modulo: 0, at: keyPath.appending(\\Self.payload))
                }

                func invariant(at keyPath: SBJValidationKeyPath) throws {
                    try _invariant(at: keyPath)
                }

                func _sbjStructuralEquals(_ other: Self) -> Bool {
                    SBJStructuralCompare.equals(self.payload, other.payload)
                }

                func sbjStructuralEquals(_ other: Self) -> Bool {
                    _sbjStructuralEquals(other)
                }
            }

            extension Model: SBJEditable, SBJSwiftUIEditable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@SBJData on property 'payload' minimum cannot exceed maximum", line: 4, column: 9, severity: .error),
                DiagnosticSpec(message: "@SBJData on property 'payload' modulo must be greater than zero", line: 4, column: 9, severity: .error)
            ],
            macros: macros
        )
    }

}
