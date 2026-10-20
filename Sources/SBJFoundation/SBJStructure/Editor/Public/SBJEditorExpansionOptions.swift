import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import Foundation

import SBJDataDefinition
/// Storage for the user's explicit disclosure choices. Implementations may persist
/// to a database, document settings, or another application-specific destination.
@MainActor
public protocol SBJEditorExpansionStore: AnyObject {
    func expansion(for identifier: SBJEditorItemIdentifier, namespace: String?) -> Bool?
    func setExpansion(_ expanded: Bool, for identifier: SBJEditorItemIdentifier, namespace: String?)
}

/// Default app-preferences storage shared between editor sessions.
@MainActor
public final class SBJEditorPreferencesExpansionStore: SBJEditorExpansionStore {
    public static let shared = SBJEditorPreferencesExpansionStore()
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private func key(for identifier: SBJEditorItemIdentifier, namespace: String?) -> String {
        // Component lengths avoid ambiguity between slashes within model keys.
        let fields = [namespace ?? ""] + identifier.components
        return "SBJEditor.expansion.v1." + fields.map { "\($0.utf8.count):\($0)" }.joined(separator: "")
    }

    public func expansion(for identifier: SBJEditorItemIdentifier, namespace: String?) -> Bool? {
        let key = key(for: identifier, namespace: namespace)
        return defaults.object(forKey: key) as? Bool
    }

    public func setExpansion(_ expanded: Bool, for identifier: SBJEditorItemIdentifier, namespace: String?) {
        defaults.set(expanded, forKey: key(for: identifier, namespace: namespace))
    }
}

/// Editor disclosure persistence, defaulting to app preferences keyed by item path.
/// A namespace allows separate documents or editor instances to keep distinct choices.
@MainActor
public struct SBJEditorExpansionOptions {
    public var store: (any SBJEditorExpansionStore)?
    public var namespace: String?

    public init(store: (any SBJEditorExpansionStore)? = SBJEditorPreferencesExpansionStore.shared,
                namespace: String? = nil) {
        self.store = store
        self.namespace = namespace
    }

    /// Keep disclosure choices only for the current presentation-model lifetime.
    public static var sessionOnly: Self { Self(store: nil) }
}
#endif
