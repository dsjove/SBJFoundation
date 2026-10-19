import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
@testable import SBJFoundationMacros

final class SBJStructureMacroTests: XCTestCase {
    // Data annotation marker macros generate no peers; the @SBJEditable umbrella
    // generator reads their syntax and applies structural metadata and diagnostics.
    private struct DataAnnotationMarker: PeerMacro {
        static func expansion(
            of node: AttributeSyntax,
            providingPeersOf declaration: some DeclSyntaxProtocol,
            in context: some MacroExpansionContext
        ) throws -> [DeclSyntax] { [] }
    }

    private let macros: [String: Macro.Type] = [
        "SBJEditable": SBJEditableMacro.self,
        "SBJEditorExclude": SBJEditorExcludeMacro.self,
        "SBJEditorProperty": SBJEditorPropertyMacro.self,
        "SBJEditorString": SBJEditorStringMacro.self,
        "SBJEditorArray": SBJEditorArrayMacro.self,
        "SBJEditorSet": SBJEditorSetMacro.self,
        "SBJEditorFontFamily": SBJEditorFontFamilyMacro.self,
        "SBJString": DataAnnotationMarker.self,
        "SBJInteger": DataAnnotationMarker.self,
        "SBJNumber": DataAnnotationMarker.self,
        "SBJOptional": DataAnnotationMarker.self,
        "SBJArray": DataAnnotationMarker.self,
        "SBJSet": DataAnnotationMarker.self,
        "SBJDictionary": DataAnnotationMarker.self,
        "SBJURL": DataAnnotationMarker.self,
        "SBJUUID": DataAnnotationMarker.self,
        "SBJDate": DataAnnotationMarker.self,
        "SBJData": DataAnnotationMarker.self,
        "SBJColor": DataAnnotationMarker.self,
    ]

    func testEmptyStructureGeneratesPublicConsumptionHooksAndEditorConformance() {
        assertMacroExpansion(
            """
            @SBJEditable
            struct Empty {}
            """,
            expandedSource: """
            struct Empty {

                static func _propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
                    switch keyPath as AnyKeyPath {

                    default:
                        return nil
                    }
                }

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [

                    ]
                }

                static var sbjMutableProperties: [SBJMutableProperty<Self>] {
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

            extension Empty: SBJMutableStructure, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }

    func testAnnotatedStoredPropertyRemainsStoredProperty() {
        assertMacroExpansion(
            """
            @SBJEditable
            struct Model {
                @SBJString(minLength: 1, maxLength: 40)
                var displayName: String
            }
            """,
            expandedSource: """
            struct Model {
                var displayName: String

                static func _propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
                    switch keyPath as AnyKeyPath {

                    default:
                        return nil
                    }
                }

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "displayName", displayName: "displayName".uncamelCased, keyPath: \\Self.displayName, kind: .text, constraints: [.textLength(min: 1, max: 40)], hints: [], info: Self.propertyInfo(for: \\Self.displayName))
                    ]
                }

                static var sbjMutableProperties: [SBJMutableProperty<Self>] {
                    [
                        SBJMutableProperty<Self>(name: "displayName".uncamelCased, \\.displayName)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "displayName".uncamelCased, \\.displayName, disclosureMode: .closed)
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

            extension Model: SBJMutableStructure, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }

    func testEditorPropertyGeneratesOnlyEditorField() {
        assertMacroExpansion(
            """
            @SBJEditable
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

                static func _propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
                    switch keyPath as AnyKeyPath {

                    default:
                        return nil
                    }
                }

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "stored", displayName: "stored".uncamelCased, keyPath: \\Self.stored, kind: .text, constraints: [], hints: [], info: Self.propertyInfo(for: \\Self.stored))
                    ]
                }

                static var sbjMutableProperties: [SBJMutableProperty<Self>] {
                    [
                        SBJMutableProperty<Self>(name: "stored".uncamelCased, \\.stored),
                        SBJMutableProperty<Self>(nonStructuralName: "image".uncamelCased, \\.image)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "stored".uncamelCased, \\.stored, disclosureMode: .closed),
                        SBJEditorPropertyDescriptor<Self>(nonStructuralName: "image".uncamelCased, \\.image)
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

            extension Model: SBJMutableStructure, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }

    func testCustomPublicHooksCanExtendGeneratedUnderscoreBehavior() {
        assertMacroExpansion(
            """
            @SBJEditable
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

                static func _propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
                    switch keyPath as AnyKeyPath {

                    default:
                        return nil
                    }
                }

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "value", displayName: "value".uncamelCased, keyPath: \\Self.value, kind: .text, constraints: [], hints: [], info: Self.propertyInfo(for: \\Self.value))
                    ]
                }

                static var sbjMutableProperties: [SBJMutableProperty<Self>] {
                    [
                        SBJMutableProperty<Self>(name: "value".uncamelCased, \\.value)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "value".uncamelCased, \\.value, disclosureMode: .closed)
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

            extension Model: SBJMutableStructure, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }

    func testNotEditableStillParticipatesInStructureButNotEditorFields() {
        assertMacroExpansion(
            """
            @SBJEditable
            struct Model {
                @SBJEditorExclude
                let identifier: String
            }
            """,
            expandedSource: """
            struct Model {
                let identifier: String

                static func _propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
                    switch keyPath as AnyKeyPath {

                    default:
                        return nil
                    }
                }

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "identifier", displayName: "identifier".uncamelCased, keyPath: \\Self.identifier, kind: .text, constraints: [], hints: [], info: Self.propertyInfo(for: \\Self.identifier))
                    ]
                }

                static var sbjMutableProperties: [SBJMutableProperty<Self>] {
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

            extension Model: SBJMutableStructure, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }

    func testUniqueByPreservesTypedKeyPathAndEscapesDescriptiveMetadata() {
        assertMacroExpansion(
            """
            @SBJEditable
            struct Model {
                @SBJArray(uniqueBy: \\Item.id)
                var items: [Item]
            }
            """,
            expandedSource: """
            struct Model {
                var items: [Item]

                static func _propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
                    switch keyPath as AnyKeyPath {

                    default:
                        return nil
                    }
                }

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "items", displayName: "items".uncamelCased, keyPath: \\Self.items, kind: .array, constraints: [.uniqueBy("\\\\Item.id"), .reorderable(true)], hints: [], info: Self.propertyInfo(for: \\Self.items))
                    ]
                }

                static var sbjMutableProperties: [SBJMutableProperty<Self>] {
                    [
                        SBJMutableProperty<Self>(name: "items".uncamelCased, \\.items)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "items".uncamelCased, \\.items, disclosureMode: .closed)
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

            extension Model: SBJMutableStructure, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }

    func testConflictingArrayUniquenessProducesDiagnostic() {
        assertMacroExpansion(
            """
            @SBJEditable
            struct Model {
                @SBJArray(unique: true, uniqueBy: \\Item.id)
                var items: [Item]
            }
            """,
            expandedSource: """
            struct Model {
                var items: [Item]

                static func _propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
                    switch keyPath as AnyKeyPath {

                    default:
                        return nil
                    }
                }

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "items", displayName: "items".uncamelCased, keyPath: \\Self.items, kind: .array, constraints: [.uniqueBy("\\\\Item.id"), .reorderable(true)], hints: [], info: Self.propertyInfo(for: \\Self.items))
                    ]
                }

                static var sbjMutableProperties: [SBJMutableProperty<Self>] {
                    [
                        SBJMutableProperty<Self>(name: "items".uncamelCased, \\.items)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "items".uncamelCased, \\.items, disclosureMode: .closed)
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

            extension Model: SBJMutableStructure, SBJSwiftUIEditable {
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
            @SBJEditable
            struct Model {
                let identifier: String
            }
            """,
            expandedSource: """
            struct Model {
                let identifier: String

                static func _propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
                    switch keyPath as AnyKeyPath {

                    default:
                        return nil
                    }
                }

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "identifier", displayName: "identifier".uncamelCased, keyPath: \\Self.identifier, kind: .text, constraints: [], hints: [], info: Self.propertyInfo(for: \\Self.identifier))
                    ]
                }

                static var sbjMutableProperties: [SBJMutableProperty<Self>] {
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

            extension Model: SBJMutableStructure, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }
    func testCodingKeysDefineMembershipAndUnannotatedTypesInferKinds() {
        assertMacroExpansion(
            """
            @SBJEditable
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

                static func _propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
                    switch keyPath as AnyKeyPath {

                    default:
                        return nil
                    }
                }

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "name", displayName: "name".uncamelCased, keyPath: \\Self.name, kind: .text, constraints: [], hints: [], info: Self.propertyInfo(for: \\Self.name)),
                        SBJPropertyMetadata<Self>(sourceName: "website", displayName: "website".uncamelCased, keyPath: \\Self.website, kind: .url, constraints: [], hints: [], info: Self.propertyInfo(for: \\Self.website))
                    ]
                }

                static var sbjMutableProperties: [SBJMutableProperty<Self>] {
                    [
                        SBJMutableProperty<Self>(name: "name".uncamelCased, \\.name),
                        SBJMutableProperty<Self>(name: "website".uncamelCased, \\.website)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "name".uncamelCased, \\.name, disclosureMode: .closed),
                        SBJEditorPropertyDescriptor<Self>(name: "website".uncamelCased, \\.website, disclosureMode: .closed)
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

            extension Model: SBJMutableStructure, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }

    func testScalarAnnotationsAddRulesAndHintsRatherThanMembership() {
        assertMacroExpansion(
            """
            @SBJEditable
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

                static func _propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
                    switch keyPath as AnyKeyPath {

                    default:
                        return nil
                    }
                }

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "identifier", displayName: "identifier".uncamelCased, keyPath: \\Self.identifier, kind: .uuid, constraints: [.uuidNonzero], hints: [], info: Self.propertyInfo(for: \\Self.identifier)),
                        SBJPropertyMetadata<Self>(sourceName: "created", displayName: "created".uncamelCased, keyPath: \\Self.created, kind: .date, constraints: [.dateRange(Date.distantPast ... Date.distantFuture)], hints: [], info: Self.propertyInfo(for: \\Self.created)),
                        SBJPropertyMetadata<Self>(sourceName: "website", displayName: "website".uncamelCased, keyPath: \\Self.website, kind: .url, constraints: [.urlKinds([.network])], hints: [], info: Self.propertyInfo(for: \\Self.website)),
                        SBJPropertyMetadata<Self>(sourceName: "color", displayName: "color".uncamelCased, keyPath: \\Self.color, kind: .color, constraints: [], hints: [.colorSupportsAlpha(false)], info: Self.propertyInfo(for: \\Self.color))
                    ]
                }

                static var sbjMutableProperties: [SBJMutableProperty<Self>] {
                    [
                        SBJMutableProperty<Self>(name: "identifier".uncamelCased, \\.identifier),
                        SBJMutableProperty<Self>(name: "created".uncamelCased, \\.created),
                        SBJMutableProperty<Self>(name: "website".uncamelCased, \\.website),
                        SBJMutableProperty<Self>(name: "color".uncamelCased, \\.color)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "identifier".uncamelCased, \\.identifier, disclosureMode: .closed),
                        SBJEditorPropertyDescriptor<Self>(name: "created".uncamelCased, \\.created, disclosureMode: .closed),
                        SBJEditorPropertyDescriptor<Self>(name: "website".uncamelCased, \\.website, disclosureMode: .closed),
                        SBJEditorPropertyDescriptor<Self>(name: "color".uncamelCased, \\.color, disclosureMode: .closed)
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

            extension Model: SBJMutableStructure, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }

    func testCodableStructWithDefaultableInitializationSynthesizesDefaultValue() {
        assertMacroExpansion(
            """
            @SBJEditable
            struct Defaultable: Codable {
                var name: String = ""
            }
            """,
            expandedSource: """
            struct Defaultable: Codable {
                var name: String = ""

                static func _propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
                    switch keyPath as AnyKeyPath {

                    default:
                        return nil
                    }
                }

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "name", displayName: "name".uncamelCased, keyPath: \\Self.name, kind: .text, constraints: [], hints: [], info: Self.propertyInfo(for: \\Self.name))
                    ]
                }

                static var sbjMutableProperties: [SBJMutableProperty<Self>] {
                    [
                        SBJMutableProperty<Self>(name: "name".uncamelCased, \\.name)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "name".uncamelCased, \\.name, disclosureMode: .closed)
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

            extension Defaultable: SBJMutableStructure, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }


    func testInheritedCodableProtocolStillSynthesizesDefaultValue() {
        assertMacroExpansion(
            """
            protocol ModelCodable: Codable {}

            @SBJEditable
            struct Model: ModelCodable {
                var name = ""
            }
            """,
            expandedSource: """
            protocol ModelCodable: Codable {}
            struct Model: ModelCodable {
                var name = ""

                static func _propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
                    switch keyPath as AnyKeyPath {

                    default:
                        return nil
                    }
                }

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "name", displayName: "name".uncamelCased, keyPath: \\Self.name, kind: .text, constraints: [], hints: [], info: Self.propertyInfo(for: \\Self.name))
                    ]
                }

                static var sbjMutableProperties: [SBJMutableProperty<Self>] {
                    [
                        SBJMutableProperty<Self>(name: "name".uncamelCased, \\.name)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "name".uncamelCased, \\.name, disclosureMode: .closed)
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

            extension Model: SBJMutableStructure, SBJSwiftUIEditable {
            }
            """,
            macros: macros
        )
    }

    func testAnnotationTypeMismatchProducesDiagnostic() {
        assertMacroExpansion(
            """
            @SBJEditable
            struct Model {
                @SBJData
                var payload: String
            }
            """,
            expandedSource: """
            struct Model {
                var payload: String

                static func _propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
                    switch keyPath as AnyKeyPath {

                    default:
                        return nil
                    }
                }

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "payload", displayName: "payload".uncamelCased, keyPath: \\Self.payload, kind: .text, constraints: [], hints: [], info: Self.propertyInfo(for: \\Self.payload))
                    ]
                }

                static var sbjMutableProperties: [SBJMutableProperty<Self>] {
                    [
                        SBJMutableProperty<Self>(name: "payload".uncamelCased, \\.payload)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "payload".uncamelCased, \\.payload, disclosureMode: .closed)
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

            extension Model: SBJMutableStructure, SBJSwiftUIEditable {
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
            @SBJEditable
            struct Model {
                @SBJData(min: 8, max: 4, modulo: 0)
                var payload: Data
            }
            """,
            expandedSource: """
            struct Model {
                var payload: Data

                static func _propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
                    switch keyPath as AnyKeyPath {

                    default:
                        return nil
                    }
                }

                static var sbjProperties: [SBJPropertyMetadata<Self>] {
                    [
                        SBJPropertyMetadata<Self>(sourceName: "payload", displayName: "payload".uncamelCased, keyPath: \\Self.payload, kind: .data, constraints: [.dataSize(min: 8, max: 4, modulo: 0)], hints: [], info: Self.propertyInfo(for: \\Self.payload))
                    ]
                }

                static var sbjMutableProperties: [SBJMutableProperty<Self>] {
                    [
                        SBJMutableProperty<Self>(name: "payload".uncamelCased, \\.payload)
                    ]
                }

                @MainActor
                static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                    [
                        SBJEditorPropertyDescriptor<Self>(name: "payload".uncamelCased, \\.payload, disclosureMode: .closed)
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

            extension Model: SBJMutableStructure, SBJSwiftUIEditable {
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
