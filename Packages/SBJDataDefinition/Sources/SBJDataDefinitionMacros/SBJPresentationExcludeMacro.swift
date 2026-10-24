import SwiftSyntax
import SwiftSyntaxMacros

/// Declarative marker; SBJStructure consumes its syntax when generating metadata.
public struct SBJPresentationExcludeMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] { [] }
}
