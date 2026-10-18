/// Source-level case identity of an enum, independently of its raw values or
/// localized display text. Generated for every enum annotated @SBJStructure.
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
public protocol SBJStructuredEnum {}
