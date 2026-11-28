import Foundation
import SBJStructure

/// Sorting is applied independently at each level of the catalog.
public enum SBJDefinitionSort: Sendable, Equatable {
    case declaration
    case alphabetical
}

public struct SBJDefinitionCatalogOptions: Sendable, Equatable {
    public var typeSort: SBJDefinitionSort
    public var propertySort: SBJDefinitionSort
    public var caseSort: SBJDefinitionSort

    public init(typeSort: SBJDefinitionSort = .alphabetical,
                propertySort: SBJDefinitionSort = .declaration,
                caseSort: SBJDefinitionSort = .declaration) {
        self.typeSort = typeSort
        self.propertySort = propertySort
        self.caseSort = caseSort
    }
}

/// A report property is a type-level declaration, not an instance value.
public struct SBJDefinitionProperty {
    public let swiftIdentifier: String
    public let displayName: String
    public let declaredType: Any.Type
    public let kind: SBJPropertyKind
    public let info: SBJNomenclature?
    public let constraints: [SBJPropertyConstraint]
    public let hints: [SBJPropertyHint]
    public let declarationIndex: Int
    public let storage: SBJPropertyStorage
    public let access: SBJPropertyAccess
    public let visibility: SBJPropertyVisibility
    /// Explicit field-presentation exclusion; traversal options determine inclusion.
    public let isPresentationExcluded: Bool
    public var isComputed: Bool { storage == .computed }

    public var title: String? {
        guard let supplied = info?.title, !supplied.isEmpty, supplied != swiftIdentifier else { return nil }
        return supplied
    }
    public var typeName: String { String(reflecting: declaredType) }

}

public struct SBJDefinitionPayload {
    public let name: String
    public let declaredType: Any.Type
    public let declarationIndex: Int
    public var typeName: String { String(reflecting: declaredType) }
}

public struct SBJDefinitionCase {
    public let swiftIdentifier: String
    public let info: SBJNomenclature?
    public let payloads: [SBJDefinitionPayload]
    /// No raw value is manufactured when the schema does not expose one.
    public let rawValueDescription: String?
    public let declarationIndex: Int

    public var title: String? {
        guard let supplied = info?.title, !supplied.isEmpty, supplied != swiftIdentifier else { return nil }
        return supplied
    }
}

/// A nonrecursive definition; references to other types are resolved through
/// registered types rather than embedding another definition in each property.
public struct SBJDefinitionType {
    public enum Content {
        case structure([SBJDefinitionProperty])
        case enumeration([SBJDefinitionCase])
    }
    public let swiftType: Any.Type
    public let swiftName: String
    public var isAtomic: Bool { SBJStructuralType.isAtomic(swiftType) }
    public let content: Content
    public let declarationIndex: Int
}

/// A snapshot of compiled declaration metadata. No model is initialized.
public struct SBJDefinitionCatalog {
    public let types: [SBJDefinitionType]
    public let options: SBJDefinitionCatalogOptions
    public let traversalOptions: SBJTraversalOptions

    /// Re-sorts the complete discovered catalog without reconstructing model values.
    public func sorted(using options: SBJDefinitionCatalogOptions) -> SBJDefinitionCatalog {
        let types = self.types.map { definition -> SBJDefinitionType in
            let content: SBJDefinitionType.Content
            switch definition.content {
            case .structure(let fields):
                content = .structure(options.propertySort == .alphabetical
                    ? fields.sorted { Self.sortNames($0.swiftIdentifier, $0.declarationIndex, $1.swiftIdentifier, $1.declarationIndex) }
                    : fields.sorted { $0.declarationIndex < $1.declarationIndex })
            case .enumeration(let cases):
                content = .enumeration(options.caseSort == .alphabetical
                    ? cases.sorted { Self.sortNames($0.swiftIdentifier, $0.declarationIndex, $1.swiftIdentifier, $1.declarationIndex) }
                    : cases.sorted { $0.declarationIndex < $1.declarationIndex })
            }
            return SBJDefinitionType(swiftType: definition.swiftType, swiftName: definition.swiftName,
                                     content: content, declarationIndex: definition.declarationIndex)
        }
        let ordered = options.typeSort == .alphabetical
            ? types.sorted { Self.sortNames($0.swiftName, $0.declarationIndex, $1.swiftName, $1.declarationIndex) }
            : types.sorted { $0.declarationIndex < $1.declarationIndex }
        return SBJDefinitionCatalog(types: ordered, options: options, traversalOptions: traversalOptions)
    }

    private static func sortNames(_ a: String, _ ai: Int, _ b: String, _ bi: Int) -> Bool {
        let comparison = a.localizedStandardCompare(b)
        return comparison == .orderedSame ? ai < bi : comparison == .orderedAscending
    }

    public init<Root: SBJStructured>(_ root: Root.Type, traversalOptions: SBJTraversalOptions = .definition, options: SBJDefinitionCatalogOptions = .init()) {
        var builder = Builder(traversalOptions: traversalOptions, options: options)
        builder.add(root)
        self = builder.build()
    }

    public struct Builder {
        private var definitions: [ObjectIdentifier: SBJDefinitionType] = [:]
        private var order: [ObjectIdentifier] = []
        private let options: SBJDefinitionCatalogOptions
        private let traversalOptions: SBJTraversalOptions

        public init(traversalOptions: SBJTraversalOptions = .definition, options: SBJDefinitionCatalogOptions = .init()) { self.options = options; self.traversalOptions = traversalOptions }

        public mutating func add<Root: SBJStructured>(_ type: Root.Type) {
            discover(type)
        }

        private mutating func registerStructure<Root: SBJStructured>(_ type: Root.Type) {
            let id = ObjectIdentifier(type)
            guard definitions[id] == nil else { return }
            var fields = SBJStructuralTraversal.definition(of: type, options: traversalOptions).map { field in
                SBJDefinitionProperty(
                    swiftIdentifier: field.sourceName, displayName: field.displayName,
                    declaredType: field.valueType, kind: field.kind,
                    info: field.info, constraints: field.constraints, hints: field.hints,
                    declarationIndex: field.ordinal, storage: field.metadata.storage,
                    access: field.metadata.access, visibility: field.metadata.visibility, isPresentationExcluded: field.metadata.isPresentationExcluded)
            }
            if options.propertySort == .alphabetical {
                fields.sort { Self.comesFirst($0.swiftIdentifier, $0.declarationIndex,
                                               $1.swiftIdentifier, $1.declarationIndex) }
            }
            definitions[id] = SBJDefinitionType(swiftType: type, swiftName: String(reflecting: type),
                                                 content: .structure(fields), declarationIndex: order.count)
            order.append(id)
        }

        /// Registers a plain or raw-value enum, including cases omitted by custom Codable.
        /// Raw values require additional compiler-generated declarations and are deliberately
        /// left unspecified rather than fabricated from case identifiers.
        public mutating func add<Enum: SBJEnumCaseIdentifiable>(_ type: Enum.Type) {
            discover(type)
        }

        private mutating func registerPlainEnum<Enum: SBJEnumCaseIdentifiable>(_ type: Enum.Type) {
            let id = ObjectIdentifier(type)
            guard definitions[id] == nil else { return }
            insertEnum(type, cases: type.sbjCaseNames.enumerated().map { index, name in
                SBJDefinitionCase(swiftIdentifier: name, info: type.sbjCaseNomenclature(for: name),
                                  payloads: [], rawValueDescription: nil, declarationIndex: index)
            })
        }

        /// Uses the typed descriptors generated by @SBJStructure for associated enums.
        public mutating func add<Enum: SBJStructuredEnum>(_ type: Enum.Type) {
            discover(type)
        }

        private mutating func registerAssociatedEnum<Enum: SBJStructuredEnum>(_ type: Enum.Type) {
            insertEnum(type, cases: type.sbjAssociatedCases.enumerated().map { index, enumCase in
                let payloads = enumCase.associatedValues.enumerated().map { ordinal, payload in
                    SBJDefinitionPayload(name: payload.name, declaredType: payload.valueType,
                                         declarationIndex: ordinal)
                }
                return SBJDefinitionCase(swiftIdentifier: enumCase.sourceName,
                                         info: type.sbjCaseNomenclature(for: enumCase.sourceName),
                                         payloads: payloads, rawValueDescription: nil,
                                         declarationIndex: index)
            })
        }

        private mutating func insertEnum<Enum>(_ type: Enum.Type, cases: [SBJDefinitionCase]) {
            let id = ObjectIdentifier(type)
            guard definitions[id] == nil else { return }
            var result = cases
            if options.caseSort == .alphabetical {
                result.sort { Self.comesFirst($0.swiftIdentifier, $0.declarationIndex,
                                              $1.swiftIdentifier, $1.declarationIndex) }
            }
            definitions[id] = SBJDefinitionType(swiftType: type, swiftName: String(reflecting: type),
                                                content: .enumeration(result), declarationIndex: order.count)
            order.append(id)
        }

        private mutating func discover(_ type: Any.Type) {
            for declared in SBJStructuralTraversal.reachableTypes(from: type, options: traversalOptions) {
                guard definitions[ObjectIdentifier(declared)] == nil else { continue }
                if let enumType = declared as? any SBJStructuredEnum.Type {
                    registerAssociatedEnum(enumType)
                } else if let structure = declared as? any SBJStructured.Type {
                    registerStructure(structure)
                } else if let enumType = declared as? any SBJEnumCaseIdentifiable.Type {
                    registerPlainEnum(enumType)
                }
            }
        }

        private static func comesFirst(_ a: String, _ ai: Int, _ b: String, _ bi: Int) -> Bool {
            let comparison = a.localizedStandardCompare(b)
            return comparison == .orderedSame ? ai < bi : comparison == .orderedAscending
        }

        public func build() -> SBJDefinitionCatalog {
            var result = order.compactMap { definitions[$0] }
            if options.typeSort == .alphabetical {
                result.sort { Self.comesFirst($0.swiftName, $0.declarationIndex,
                                              $1.swiftName, $1.declarationIndex) }
            }
            return SBJDefinitionCatalog(types: result, options: options, traversalOptions: traversalOptions)
        }
    }

    private init(types: [SBJDefinitionType], options: SBJDefinitionCatalogOptions, traversalOptions: SBJTraversalOptions) {
        self.traversalOptions = traversalOptions
        self.types = types
        self.options = options
    }
}

/// Human-readable type notation for report output only. Reflected types and
/// catalog identities retain their original, fully qualified spelling.
public enum SBJDefinitionTypeDisplay {
    public static func format(_ reflectedName: String) -> String {
        // Remove only a Swift *module qualifier*, not the matching substring
        // inside a user-defined module such as MySwift.Models.
        let textWithoutSwiftModule = reflectedName.replacingOccurrences(
            of: #"(?<![\p{L}\p{N}_.])Swift\."#,
            with: "",
            options: .regularExpression
        )
        var text = textWithoutSwiftModule
        // String(reflecting:) spells optionals as Optional<T>, including nested forms.
        // Rewrite from the inside out so Optional<Array<Optional<Int>>> works too.
        while let range = text.range(of: "Optional<", options: .backwards) {
            let start = range.upperBound
            var depth = 1
            var cursor = start
            while cursor < text.endIndex && depth > 0 {
                if text[cursor] == "<" { depth += 1 }
                if text[cursor] == ">" { depth -= 1 }
                if depth > 0 { cursor = text.index(after: cursor) }
            }
            guard depth == 0 else { break }
            let wrapped = String(text[start..<cursor])
            text.replaceSubrange(range.lowerBound...cursor, with: "\(wrapped)?")
        }
        return text
    }
}
