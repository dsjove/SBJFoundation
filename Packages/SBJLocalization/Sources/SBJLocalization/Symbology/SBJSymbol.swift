import Foundation

/// An image used as UI symbology, not arbitrary user-provided or document content.
/// Bundled references resolve in the bundle supplied by their caller.
public enum SBJSymbol: Hashable, Sendable {
    case system(String)
    case asset(String, bundle: Bundle? = nil)
    case bundleImage(name: String, extension: String? = nil, subdirectory: String? = nil, bundle: Bundle? = nil)

    public var isEmpty: Bool {
        switch self {
        case .system(let name): return name.isEmpty
        case .asset(let name, _): return name.isEmpty
        case .bundleImage(let name, _, _, _): return name.isEmpty
        }
    }
}
