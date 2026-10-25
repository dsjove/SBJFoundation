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
        return SBJDefinitionCatalog(types: ordered, options: options)
    }

    private static func sortNames(_ a: String, _ ai: Int, _ b: String, _ bi: Int) -> Bool {
        let comparison = a.localizedStandardCompare(b)
        return comparison == .orderedSame ? ai < bi : comparison == .orderedAscending
    }

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
            // Traverse declarations recursively; no model instances are created.
            // Register the parent before its children to terminate recursive schemas.
            for field in fields { discover(field.declaredType) }
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
            for enumCase in result {
                for payload in enumCase.payloads { discover(payload.declaredType) }
            }
        }

        private mutating func discover(_ type: Any.Type) {
            if let wrapped = type as? SBJReportTypeWrapper.Type {
                for child in wrapped.sbjReportElementTypes { discover(child) }
                return
            }
            // Associated-value enums must be tested before general structures.
            if let enumType = type as? any SBJStructuredEnum.Type {
                addAssociatedEnum(enumType)
            } else if let structure = type as? any SBJStructured.Type {
                addStructure(structure)
            } else if let enumType = type as? any SBJEnumCaseIdentifiable.Type {
                addPlainEnum(enumType)
            }
        }

        private mutating func addStructure<T: SBJStructured>(_ type: T.Type) { add(type) }
        private mutating func addAssociatedEnum<T: SBJStructuredEnum>(_ type: T.Type) { add(type) }
        private mutating func addPlainEnum<T: SBJEnumCaseIdentifiable>(_ type: T.Type) { add(type) }

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

/// Exposes generic wrapper element types without constructing wrapped values.
private protocol SBJReportTypeWrapper {
    static var sbjReportElementTypes: [Any.Type] { get }
}

extension Optional: SBJReportTypeWrapper {
    static var sbjReportElementTypes: [Any.Type] { [Wrapped.self] }
}

extension Array: SBJReportTypeWrapper {
    static var sbjReportElementTypes: [Any.Type] { [Element.self] }
}

extension Set: SBJReportTypeWrapper {
    static var sbjReportElementTypes: [Any.Type] { [Element.self] }
}

extension Dictionary: SBJReportTypeWrapper {
    static var sbjReportElementTypes: [Any.Type] { [Key.self, Value.self] }
}
