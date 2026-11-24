import SwiftSyntax
import SwiftSyntaxMacros

/// Marker read by the surrounding @SBJStructure expansion.
public struct SBJComputedMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] { [] }
}
