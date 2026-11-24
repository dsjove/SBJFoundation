import SwiftSyntax
import SwiftSyntaxMacros

/// Marker consumed by `SBJStructureMacro`. It intentionally emits no peer.
public struct SBJNumberMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] { [] }
}
