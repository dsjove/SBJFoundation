import Foundation
import SBJLocalization

/// UI-independent description of a model annotated with `@SBJStructure`.
///
/// SBJStructure declarations describe the model; they do not intercept property
/// access or automatically enforce invariants. Consumers explicitly choose when
/// to inspect metadata, content state, or validation rules.
public protocol SBJStructured: Codable, HasContentCheckable, SBJStructuralComparable, SBJSwiftExpressionRepresentable {
    /// Structural metadata for the coded stored properties of this model.
    static var sbjProperties: [SBJPropertyMetadata<Self>] { get }

    /// Supplemental documentation and accessibility information for a property.
    ///
    /// The default implementation returns `nil`. Applications may implement this
    /// method to provide documentation consumed by editors or any other UI/tool.
    static func propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo?
    static func _propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo?

    /// Returns a sensible default instance when the structured type can be
    /// constructed without application-specific context. `@SBJStructure`
    /// synthesizes this when a zero-argument initialization is provably valid.
    static func sbjDefaultValue() -> Self?

    /// Initializer parameter mapping used by Swift source export.
    static var sbjSwiftInitializerParameters: [SBJSwiftInitializerParameter] { get }

    /// Stored coded properties that can be assigned after default construction.
    static var sbjSwiftWritablePropertyNames: Set<String> { get }

    /// Recursively reports whether any structural property contains empty content.
    /// Consumers may treat application-defined types as atomic traversal leaves.
    func sbjContainsEmptyContent(treatingAsLeaf: (Any.Type) -> Bool) -> Bool

    /// Finds every `SBJReferencedContentID` referenced by this structured value and its structured descendants.
    func sbjReferencedContentOccurrences(path: String) -> [SBJReferencedContentOccurrence]
}

public extension SBJStructured {
    /// Assembles declaration-site metadata with the property's runtime accessibility.
    /// Returns nil when neither source contributes accessibility semantics.
    func accessibilityItem<Value>(for keyPath: KeyPath<Self, Value>) -> AccessibleItem? {
        let info = Self.propertyInfo(for: keyPath)
        let values = self[keyPath: keyPath] as? any SBJTextPresentable
        guard info != nil || values != nil else { return nil }
        return AccessibleItem(
            label: info?.accessibilityLabel,
            hint: info?.accessibilityHint,
            value: values?.accessibilityValue
        )
    }

    static func propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
        _propertyInfo(for: keyPath)
    }

    static func _propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? { nil }

    static func sbjDefaultValue() -> Self? { nil }

    func sbjReferencedContentOccurrences(path: String = "") -> [SBJReferencedContentOccurrence] {
        Self.sbjProperties.flatMap { $0.referencedContentOccurrences(in: self, path: path) }
    }

    /// Returns the unique semantic resource identifiers referenced by this structured value.
    func sbjReferencedContentIDs() -> Set<SBJReferencedContentID> {
        Set(sbjReferencedContentOccurrences().map(\.id))
    }

    func sbjContainsEmptyContent(treatingAsLeaf: (Any.Type) -> Bool = { _ in false }) -> Bool {
        if !hasContent { return true }
        if treatingAsLeaf(Self.self) { return false }
        return Self.sbjProperties.contains { property in
            property.containsEmptyContent(in: self, treatingAsLeaf: treatingAsLeaf)
        }
    }

    static var sbjSwiftWritablePropertyNames: Set<String> { [] }

    static var sbjSwiftInitializerParameters: [SBJSwiftInitializerParameter] {
        sbjProperties.map {
            .init(propertyName: $0.sourceName, label: $0.sourceName)
        }
    }

    func sbjSwiftExpression(using encoder: SBJSwiftEncoder, nested: Bool) -> String {
        let propertiesByName = Dictionary(uniqueKeysWithValues: Self.sbjProperties.map {
            ($0.sourceName, $0)
        })
        let parameters = Self.sbjSwiftInitializerParameters
        // Source construction must cover every coded property exactly once.
        // An unavailable or incomplete constructor can use Codable instead.
        let covered = parameters.map(\.propertyName)
        guard !parameters.isEmpty,
              covered.count == propertiesByName.count,
              Set(covered).count == covered.count,
              covered.allSatisfy({ propertiesByName[$0] != nil }) else {
            // A default-constructible model can be reconstructed using a
            // self-contained Swift closure, provided its entire coded schema is
            // writable. Do not attempt assignments to `let` properties.
            if Self.sbjDefaultValue() != nil,
               Set(propertiesByName.keys).isSubset(of: Self.sbjSwiftWritablePropertyNames) {
                let assignments = Self.sbjProperties.map { property in
                    let value = self[keyPath: property.keyPath]
                    return (property.sourceName, encoder.expression(for: value))
                }
                return encoder.mutableStructureExpression(
                    typeName: String(describing: Self.self),
                    assignments: assignments
                )
            }
            return encoder.codableReconstructionExpression(for: self)
                ?? "/* No complete reconstruction for \(Self.self) */"
        }
        let arguments = parameters.map { parameter -> SBJSwiftArgument in
            let metadata = propertiesByName[parameter.propertyName]!
            let value = self[keyPath: metadata.keyPath]
            return encoder.argument(value, parameter: parameter, info: metadata.info)
        }
        return encoder.structuredExpression(
            typeName: String(describing: Self.self),
            nested: nested,
            arguments: arguments
        )
    }

    /// Returns the generated structural metadata for a specific property.
    static func propertyMetadata<Value>(
        for keyPath: KeyPath<Self, Value>
    ) -> SBJPropertyMetadata<Self>? {
        sbjProperties.first { $0.keyPath == keyPath }
    }
}

/// UI-independent metadata describing one coded stored property on `Root`.
///
/// The key path identifies the actual model property. `sourceName` is the Swift
/// declaration name, while `displayName` provides SBJStructure's default human-
/// readable presentation. Consumers are free to ignore either value.
public struct SBJPropertyMetadata<Root: SBJStructured> {
    public let sourceName: String
    public let displayName: String
    public let keyPath: PartialKeyPath<Root>
    public let kind: SBJPropertyKind
    public let constraints: [SBJPropertyConstraint]
    public let hints: [SBJPropertyHint]
    public let info: SBJPropertyInfo?
    private let validateValue: (Root) -> SBJValidationError?
    private let containsEmptyValue: (Root, (Any.Type) -> Bool) -> Bool
    private let structurallyEqualValue: (Root, Root) -> Bool
    private let referencedContentOccurrencesValue: (Root, String) -> [SBJReferencedContentOccurrence]

    public init<Value>(
        sourceName: String,
        displayName: String,
        keyPath: KeyPath<Root, Value>,
        kind: SBJPropertyKind = .inferred,
        constraints: [SBJPropertyConstraint] = [],
        hints: [SBJPropertyHint] = [],
        info: SBJPropertyInfo? = nil,
        structurallyEqual: @escaping (Value, Value) -> Bool = { lhs, rhs in
            SBJStructuralCompare.equals(lhs, rhs)
        }
    ) {
        self.sourceName = sourceName
        self.displayName = displayName
        self.keyPath = keyPath
        self.kind = kind
        self.constraints = constraints
        self.hints = hints
        self.info = info
        self.validateValue = { root in
            SBJInvariantCheck.validationError(
                root[keyPath: keyPath],
                at: SBJValidationKeyPath(keyPath)
            )
        }
        self.containsEmptyValue = { root, treatingAsLeaf in
            SBJContentCheck.containsEmptyContent(
                root[keyPath: keyPath],
                treatingAsLeaf: treatingAsLeaf
            )
        }
        self.structurallyEqualValue = { lhs, rhs in
            structurallyEqual(lhs[keyPath: keyPath], rhs[keyPath: keyPath])
        }
        self.referencedContentOccurrencesValue = { root, path in
            SBJReferencedContentTraversal.occurrences(
                in: root[keyPath: keyPath],
                path: SBJReferencedContentTraversal.appending(sourceName, to: path)
            )
        }
    }

    /// Finds resource references in this property and its structured descendants.
    public func referencedContentOccurrences(in root: Root, path: String = "") -> [SBJReferencedContentOccurrence] {
        referencedContentOccurrencesValue(root, path)
    }

    /// Compares this property between two roots using structural-value semantics.
    public func structurallyEquals(in lhs: Root, _ rhs: Root) -> Bool {
        structurallyEqualValue(lhs, rhs)
    }

    /// Validates this property value using its structural key path.
    public func validationError(in root: Root) -> SBJValidationError? {
        validateValue(root)
    }

    /// Recursively checks this property's value for empty content.
    public func containsEmptyContent(
        in root: Root,
        treatingAsLeaf: (Any.Type) -> Bool = { _ in false }
    ) -> Bool {
        containsEmptyValue(root, treatingAsLeaf)
    }
}

/// The structural type category inferred from the Swift property declaration.
///
/// Property annotations refine rules and hints; they are not required to establish
/// the kind. ``inferred`` is reserved for model types that do not map to a built-in
/// SBJStructure category.
public enum SBJPropertyKind: Sendable, Equatable {
    case inferred
    case text
    case bool
    case integer
    case number
    case optional
    case array
    case set
    case dictionary
    case url
    case uuid
    case date
    case data
    case color
}

/// A business rule declared for a model property.
///
/// These values are descriptive metadata. They do not intercept assignment or
/// enforce themselves. Validation and other consumers explicitly interpret them.
public enum SBJPropertyConstraint: Sendable, Equatable {
    case stringRules(SBJStringRules)
    case integerRules(SBJIntegerRules)
    case numberRules(SBJNumberRules)
    case optionalRules(SBJOptionalRules)
    /// Whether changing the unit is prohibited by the property definition.
    case unitMutable(Bool)
    /// Preferred unit for creating a new measurement in this field.
    case defaultUnit(SBJDefaultUnit)
    case unitSystem(MeasurementSystem)
    case arrayRules(SBJArrayRules)
    case setRules(SBJSetRules)
    case dictionaryRules(SBJDictionaryRules)
    case dictionaryKeyRule(SBJDictionaryMemberRuleValue)
    case dictionaryValueRule(SBJDictionaryMemberRuleValue)
    case unique
    /// Human-readable representation of the compiler-checked element key path.
    /// Generated validation retains and uses the actual key path expression.
    case uniqueBy(String)
    case dataRules(SBJDataRules)
    case uuidRules(SBJUUIDRules)
    case dateRules(SBJDateRules)
    case urlRules(SBJURLRules)
}

/// Non-invariant usage or presentation information declared on a model property.
/// Consumers may honor these hints, but they do not participate in validation.
public enum SBJPropertyHint: Sendable, Equatable {
    case fieldPresentation(SBJFieldPresentationValue)
    /// Presentation of each Array or Set element (second annotation occurrence).
    case elementFieldPresentation(SBJFieldPresentationValue)
    case arrayPresentation(SBJArrayPresentationValue)
    case setPresentation(SBJSetPresentationValue)
    case dictionaryPresentation(SBJDictionaryPresentationValue)
    case stringPresentation(SBJStringPresentationValue)
    case unitValuePresentation(SBJUnitValuePresentationValue)
    case colorPresentation(SBJColorPresentationValue)
    /// Human-readable representation of the compiler-checked item-title key path.
    case itemTitle(String)
}
