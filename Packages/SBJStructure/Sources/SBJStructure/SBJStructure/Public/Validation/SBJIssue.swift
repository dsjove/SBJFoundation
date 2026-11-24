import Foundation

/// UI-independent description of a diagnostic discovered while inspecting a value.
///
/// The issue kind is generic so consumers can define domain-specific categories
/// without coupling the issue container to an editor, logger, or presentation layer.
public struct SBJIssue<Kind: Hashable>: Identifiable, Hashable {
    public let kind: Kind
    public let path: String
    public let typeName: String
    public let valueDescription: String?
    public let message: String?

    public var id: Self { self }

    public init(
        kind: Kind,
        path: String,
        typeName: String,
        valueDescription: String?,
        message: String? = nil
    ) {
        self.kind = kind
        self.path = path
        self.typeName = typeName
        self.valueDescription = valueDescription
        self.message = message
    }

    /// Removes duplicate or ancestor reports of the same underlying issue.
    ///
    /// Issue discovery often happens in independent recursive passes. A child
    /// failure can therefore also be surfaced by an ancestor whose validation
    /// simply propagated that same failure. This helper keeps the most specific
    /// location while leaving genuinely distinct diagnostics untouched.
    ///
    /// Redundancy is intentionally conservative: two issues must have the same
    /// kind, type name, and value description before their paths are compared.
    /// This makes the reduction suitable for non-editor consumers such as logs,
    /// alternate editors, and validation reports.
    public static func removingRedundantIssues(from issues: [Self]) -> [Self] {
        issues.enumerated().compactMap { index, issue in
            let isRedundant = issues.enumerated().contains { otherIndex, other in
                guard index != otherIndex,
                      issue.kind == other.kind,
                      issue.typeName == other.typeName,
                      issue.valueDescription == other.valueDescription,
                      issue.message == other.message else {
                    return false
                }

                if issue.path == other.path {
                    // Preserve the first occurrence of an exact duplicate.
                    return otherIndex < index
                }

                // Prefer a child report over an ancestor report when both are
                // describing the same failure. Supports editor display paths
                // ("Parent • Child") and structural paths (dot/collection syntax).
                if Self.path(other.path, isDescendantOf: issue.path) {
                    return true
                }

                // Structural validation may report the same child once from a
                // root pass and once from the child's own pass. The root form
                // carries an extra `\Root.self.` prefix; prefer the shorter,
                // directly-addressed child path.
                if issue.path.contains(".self."), Self.path(issue.path, wraps: other.path) {
                    return true
                }

                return false
            }

            return isRedundant ? nil : issue
        }
    }

    private static func path(_ candidate: String, isDescendantOf ancestor: String) -> Bool {
        guard !ancestor.isEmpty, candidate.hasPrefix(ancestor), candidate.count > ancestor.count else {
            return false
        }
        let remainder = candidate.dropFirst(ancestor.count)
        return remainder.hasPrefix(" • ") ||
            remainder.hasPrefix(".") ||
            remainder.hasPrefix("[") ||
            remainder.hasPrefix("{")
    }

    private static func path(_ candidate: String, wraps directPath: String) -> Bool {
        guard !directPath.isEmpty, candidate.count > directPath.count, candidate.hasSuffix(directPath) else {
            return false
        }
        let prefix = candidate.dropLast(directPath.count)
        return prefix.hasSuffix(".")
    }
}

/// Small reusable collection helper for diagnostics produced by independent passes.
public struct SBJIssueCollection<Issue> {
    public private(set) var issues: [Issue]

    public init(_ issues: [Issue] = []) {
        self.issues = issues
    }

    public mutating func append(_ issue: Issue) {
        issues.append(issue)
    }

    public mutating func append(contentsOf newIssues: some Sequence<Issue>) {
        issues.append(contentsOf: newIssues)
    }

    public mutating func removeAll(where shouldBeRemoved: (Issue) throws -> Bool) rethrows {
        try issues.removeAll(where: shouldBeRemoved)
    }

    public func uniqued<Key: Hashable>(by key: (Issue) -> Key) -> [Issue] {
        var seen = Set<Key>()
        return issues.filter { seen.insert(key($0)).inserted }
    }
}

/// Shared, presentation-independent value description used by diagnostics and search.
public enum SBJValueDescription {
    public static func describe(_ value: Any) -> String? {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            guard let child = mirror.children.first else { return nil }
            return describe(child.value)
        }

        if let described = value as? any CustomStringConvertible {
            let text = described.description.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }

        if mirror.displayStyle == .enum {
            let text = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
        return nil
    }
}

public enum SBJStructureIssueKind: Hashable, Sendable {
    case validation
}

public typealias SBJStructureIssue = SBJIssue<SBJStructureIssueKind>

/// UI-independent diagnostics for an `SBJStructured` model.
public enum SBJStructureDiagnostics {
    public static func issues<Value: SBJStructured>(for value: Value) -> [SBJStructureIssue] {
        var collection = SBJIssueCollection<SBJStructureIssue>()

        for property in Value.sbjProperties {
            if let error = property.validationError(in: value) {
                collection.append(
                    SBJStructureIssue(
                        kind: .validation,
                        path: error.keyPath.description,
                        typeName: "Validation",
                        valueDescription: error.valueDescription,
                        message: error.message
                    )
                )
            }
        }

        if let error = SBJInvariantCheck.validationError(value, at: SBJValidationKeyPath(\Value.self)) {
            collection.append(
                SBJStructureIssue(
                    kind: .validation,
                    path: error.keyPath.description,
                    typeName: "Validation",
                    valueDescription: error.valueDescription,
                    message: error.message
                )
            )
        }

        return collection.uniqued { $0 }
    }
}
