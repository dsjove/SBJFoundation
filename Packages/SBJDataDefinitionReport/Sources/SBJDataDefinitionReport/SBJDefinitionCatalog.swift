import Foundation
import SBJDataDefinition

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
    public let info: SBJPropertyInfo?
    public let constraints: [SBJPropertyConstraint]
    public let hints: [SBJPropertyHint]
    public let declarationIndex: Int
    public let isStored: Bool

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
    public let info: SBJPropertyInfo?
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
    public let content: Content
    public let declarationIndex: Int
}

/// A snapshot of compiled declaration metadata. No model is initialized.
public struct SBJDefinitionCatalog {
    public let types: [SBJDefinitionType]
    public let options: SBJDefinitionCatalogOptions

    public init<Root: SBJStructured>(_ root: Root.Type, options: SBJDefinitionCatalogOptions = .init()) {
        var builder = Builder(options: options)
        builder.add(root)
        self = builder.build()
    }

    public struct Builder {
        private var definitions: [ObjectIdentifier: SBJDefinitionType] = [:]
        private var order: [ObjectIdentifier] = []
        private let options: SBJDefinitionCatalogOptions

        public init(options: SBJDefinitionCatalogOptions = .init()) { self.options = options }

        public mutating func add<Root: SBJStructured>(_ type: Root.Type) {
            let id = ObjectIdentifier(type)
            guard definitions[id] == nil else { return }
            var fields = SBJStructuralTraversal.definition(of: type).map { field in
                SBJDefinitionProperty(
                    swiftIdentifier: field.sourceName, displayName: field.displayName,
                    declaredType: field.valueType, kind: field.kind,
                    info: field.info, constraints: field.constraints, hints: field.hints,
                    declarationIndex: field.ordinal, isStored: true)
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
            let id = ObjectIdentifier(type)
            guard definitions[id] == nil else { return }
            insertEnum(type, cases: type.sbjCaseNames.enumerated().map { index, name in
                SBJDefinitionCase(swiftIdentifier: name, info: type.sbjCaseInfo(for: name),
                                  payloads: [], rawValueDescription: nil, declarationIndex: index)
            })
        }

        /// Uses the typed descriptors generated by @SBJStructure for associated enums.
        public mutating func add<Enum: SBJStructuredEnum>(_ type: Enum.Type) {
            insertEnum(type, cases: type.sbjAssociatedCases.enumerated().map { index, enumCase in
                let collector = PayloadCollector<Enum>()
                for payload in enumCase.associatedValues { payload.visit(collector) }
                return SBJDefinitionCase(swiftIdentifier: enumCase.sourceName,
                                         info: type.sbjCaseInfo(for: enumCase.sourceName),
                                         payloads: collector.payloads, rawValueDescription: nil,
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
            return SBJDefinitionCatalog(types: result, options: options)
        }
    }

    private init(types: [SBJDefinitionType], options: SBJDefinitionCatalogOptions) {
        self.types = types
        self.options = options
    }
}

private final class PayloadCollector<Root>: SBJTypedAssociatedValueVisitor {
    var payloads: [SBJDefinitionPayload] = []
    func visit<Value: Codable>(name: String, get: @escaping (Root) -> Value,
                               set: @escaping (inout Root, Value) -> Void) {
        payloads.append(SBJDefinitionPayload(name: name, declaredType: Value.self,
                                             declarationIndex: payloads.count))
    }
}
