import SwiftSyntax
import SwiftSyntaxMacros

/// Marker consumed by SBJStructureMacro; no generated peer members.
public struct SBJDurationMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] { [] }
}
