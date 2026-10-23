import Foundation

/// A compile-time domain vocabulary of semantic symbols.
/// Conforming types define their symbols once, for both Swift UI and Help.
@dynamicMemberLookup
public protocol SBJSymbolSet {
    static var all: [String: SBJSymbol] { get }
}

public extension SBJSymbolSet {
    static subscript(dynamicMember name: String) -> SBJSymbol {
        all[name] ?? SBJSymbol.system("exclamationmark.questionmark")
    }
}
