/// A key-path-based validation location. Property components are real Swift
/// key paths; collection locations retain enough information to identify the
/// element that failed validation without turning model properties into strings.
///
/// `description` is intended for presentation. `debugDescription` preserves the
/// exact structural key-path form used for diagnostics and debugging.
public struct SBJValidationKeyPath: @unchecked Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    fileprivate enum Component {
        case property(AnyKeyPath)
        case index(Int, title: String?)
        case key(String)
        case element(String, title: String?)
    }

    fileprivate var components: [Component]

    public init<Root, Value>(_ keyPath: KeyPath<Root, Value>) {
        self.components = [.property(keyPath)]
    }

    fileprivate init(components: [Component]) {
        self.components = components
    }

    /// The root validation location, before any property or collection component.
    public static var root: Self { .init(components: []) }

    public func appending<Root, Value>(_ keyPath: KeyPath<Root, Value>) -> Self {
        .init(components: components + [.property(keyPath)])
    }

    public func appending(index: Int, title: String? = nil) -> Self {
        .init(components: components + [.index(index, title: title)])
    }

    /// Appends a dictionary key. The key is retained as a display description;
    /// the owning model property remains represented by its real Swift key path.
    public func appending<Key>(key: Key) -> Self {
        .init(components: components + [.key(String(describing: key))])
    }

    /// Appends a set member description. Sets have no stable numeric index, so
    /// validation identifies the member rather than manufacturing an ordering.
    public func appending<Element>(element: Element, title: String? = nil) -> Self {
        .init(components: components + [.element(String(describing: element), title: title)])
    }

    public func contains(property keyPath: AnyKeyPath) -> Bool {
        components.contains { component in
            if case .property(let candidate) = component { return candidate == keyPath }
            return false
        }
    }

    /// Human-readable path for presentation in validation UI.
    ///
    /// Swift type names are omitted. Collection elements use the title captured
    /// when validation ran when one was supplied by structure metadata.
    public var description: String {
        components.compactMap { component in
            switch component {
            case .property(let keyPath):
                return Self.presentationPropertyName(for: keyPath)
            case .index(let index, let title):
                return title ?? "[\(index)]"
            case .key(let key):
                return key
            case .element(let element, let title):
                return title ?? element
            }
        }
        .filter { !$0.isEmpty }
        .joined(separator: " › ")
    }

    /// Exact structural key-path description retained for diagnostics/debugging.
    public var debugDescription: String {
        var result = ""
        for component in components {
            switch component {
            case .property(let keyPath):
                if !result.isEmpty { result += "." }
                result += String(describing: keyPath)
            case .index(let index, _):
                result += "[\(index)]"
            case .key(let key):
                result += "[\(String(reflecting: key))]"
            case .element(let element, _):
                result += "{\(element)}"
            }
        }
        return result
    }

    private static func presentationPropertyName(for keyPath: AnyKeyPath) -> String? {
        let raw = String(describing: keyPath)
        guard let property = raw.split(separator: ".").last.map(String.init),
              property != "self" else {
            return nil
        }
        return property.uncamelCased
    }
}
