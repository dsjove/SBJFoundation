import Foundation

/// Stable identity for a resource referenced by an SBJStructure model.
///
/// The identifier is deliberately string-backed so hand-authored Swift documents
/// can use readable, stable resource names while generated/user resources may use UUID strings.
public struct SBJResourceID: RawRepresentable, SBJFoundationType, Hashable, Sendable, Comparable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// One discovered use of a resource inside an SBJStructure value graph.
public struct SBJResourceUsage: Sendable, Equatable, Hashable {
    public let id: SBJResourceID
    public let path: String

    public init(id: SBJResourceID, path: String) {
        self.id = id
        self.path = path
    }
}

/// Structural resource-reference discovery used by persistence, diagnostics and tools.
///
/// Traversal enters only generated `SBJStructured` properties and standard value
/// containers (optional/collection/set/dictionary/tuple/associated enum payloads).
/// Arbitrary non-structured objects are treated as leaves.
public enum SBJResourceDiscovery {
    public static func usages<Value>(in value: Value, path: String = "") -> [SBJResourceUsage] {
        collect(value, path: path)
    }

    private static func collect(_ value: Any, path: String) -> [SBJResourceUsage] {
        if let id = value as? SBJResourceID {
            return [.init(id: id, path: path)]
        }
        if let structured = value as? any SBJStructured {
            return structured.sbjResourceUsages(path: path)
        }

        let mirror = Mirror(reflecting: value)
        switch mirror.displayStyle {
        case .optional:
            guard let child = mirror.children.first else { return [] }
            return collect(child.value, path: path)
        case .collection, .set:
            return mirror.children.enumerated().flatMap { index, child in
                collect(child.value, path: appending("[\(index)]", to: path, separator: ""))
            }
        case .dictionary:
            return mirror.children.enumerated().flatMap { index, child -> [SBJResourceUsage] in
                let pair = Array(Mirror(reflecting: child.value).children)
                guard pair.count == 2 else { return [] }
                return collect(pair[0].value, path: appending("[\(index)].key", to: path))
                    + collect(pair[1].value, path: appending("[\(index)].value", to: path))
            }
        case .tuple:
            return mirror.children.enumerated().flatMap { index, child in
                let component = child.label ?? "[\(index)]"
                return collect(child.value, path: appending(component, to: path, separator: component.hasPrefix("[") ? "" : "."))
            }
        case .enum:
            // Structured enums expose their stored associated payload only through reflection.
            return mirror.children.flatMap { child in
                collect(child.value, path: appending(child.label ?? "value", to: path))
            }
        default:
            return []
        }
    }

    static func appending(_ component: String, to path: String, separator: String = ".") -> String {
        guard !path.isEmpty else { return component }
        return path + separator + component
    }
}
