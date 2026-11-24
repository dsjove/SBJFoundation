import SwiftSyntax
import SwiftSyntaxMacros

/// Declarative metadata consumed by the SBJStructure generator.
public struct SBJFieldPresentationMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] { [] }
}
