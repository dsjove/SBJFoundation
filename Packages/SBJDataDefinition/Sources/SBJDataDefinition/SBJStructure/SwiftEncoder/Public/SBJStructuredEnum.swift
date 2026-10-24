import SBJLocalization

/// Source-level case identity of an enum, independently of its raw values or
/// localized display text. Generated for every enum annotated @SBJEditable.
public protocol SBJEnumCaseIdentifiable {
    static var sbjCaseNames: [String] { get }
    var sbjCaseName: String { get }
    static func sbjCaseInfo(for caseName: String) -> SBJPropertyInfo?
}

public extension SBJEnumCaseIdentifiable {
    static func sbjCaseInfo(for caseName: String) -> SBJPropertyInfo? { nil }

    static func sbjCaseName(for value: Any) -> String? {
        (value as? Self)?.sbjCaseName
    }
}

/// Marker for an annotated enum with one or more associated-value payloads.
/// Payload-aware consumers should use this rather than treating all enums with
/// case-name metadata as recursive structures.
public protocol SBJStructuredEnum: SBJEnumCaseIdentifiable, Codable, SBJDefaultValueCreatable, SBJStructuralComparable {
    static var sbjAssociatedCases: [SBJAssociatedCase<Self>] { get }
}

/// A presentation-neutral, type-preserving consumer of an enum payload.
public protocol SBJTypedAssociatedValueVisitor<Root>: AnyObject {
    associatedtype Root
    func visit<Value: Codable>(
        name: String,
        get: @escaping (Root) -> Value,
        set: @escaping (inout Root, Value) -> Void
    )
}

/// One payload of an associated-value enum. The typed accessor is retained by
/// a generic closure, so no `Any` casts or SwiftUI dependencies are required.
public struct SBJAssociatedValue<Root> {
    public let name: String
    private let dispatch: (any SBJTypedAssociatedValueVisitor<Root>) -> Void

    public init<Value: Codable>(
        name: String,
        get: @escaping (Root) -> Value,
        set: @escaping (inout Root, Value) -> Void
    ) {
        self.name = name
        self.dispatch = { $0.visit(name: name, get: get, set: set) }
    }

    public func visit(_ visitor: any SBJTypedAssociatedValueVisitor<Root>) {
        dispatch(visitor)
    }
}

/// Case matching, optional creation, and payload access, independent of UI.
public struct SBJAssociatedCase<Root> {
    public let sourceName: String
    public let associatedValues: [SBJAssociatedValue<Root>]
    private let matchesValue: (Root) -> Bool
    private let createValue: () -> Root?

    public init(
        sourceName: String,
        matches: @escaping (Root) -> Bool,
        makeDefault: @escaping () -> Root?,
        associatedValues: [SBJAssociatedValue<Root>]
    ) {
        self.sourceName = sourceName
        self.matchesValue = matches
        self.createValue = makeDefault
        self.associatedValues = associatedValues
    }

    public func matches(_ value: Root) -> Bool { matchesValue(value) }
    public func makeDefaultValue() -> Root? { createValue() }
}

